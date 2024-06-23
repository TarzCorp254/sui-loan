#[allow(lint(self_transfer))] // Allow self-transfer lint
module loan::loan { // Define the module loan::loan
    use sui::tx_context::{sender, TxContext}; // Import the sender function and TxContext from sui::tx_context
    use sui::coin::{Coin, CoinMetadata, coin}; // Import Coin, CoinMetadata, and coin module from sui::coin
    use sui::balance::{Balance, balance}; // Import Balance and balance module from sui::balance
    use sui::bag::{Bag, bag}; // Import Bag and bag module from sui::bag
    use sui::clock::{Clock, timestamp_ms}; // Import Clock and timestamp_ms from sui::clock
    use sui::object::{UID, object}; // Import UID and object module from sui::object
    use sui::transfer::{self, share_object}; // Import transfer and share_object from sui::transfer
    use sui::mutex::{Mutex, mutex}; // Import Mutex and mutex module from sui::mutex
    use std::string::{String, string}; // Import String and string module from std::string
    use sui::event::emit; // Import emit function from sui::event

    /// Error Constants ///
    const E_INSUFFICIENT_FUNDS: u64 = 1; // Error code for insufficient funds
    const E_INVALID_CAP: u64 = 4; // Error code for invalid loan cap
    const E_LOAN_ALREADY_REPAID: u64 = 5; // Error code for already repaid loan
    const E_INSUFFICIENT_WITHDRAWAL_FUNDS: u64 = 6; // Error code for insufficient funds for withdrawal

    const INTEREST_RATE: u128 = 5; // Interest rate constant

    // Type that stores user loan data:
    public struct LoanAccount<phantom COIN> has key { // Define LoanAccount struct with a phantom type parameter COIN and key ability
        id: UID, // Unique identifier for the loan
        inner: address, // Address of the loan account
        loan_date: u64, // Timestamp of when the loan was issued
        last_payment_date: u64, // Timestamp of the last repayment
        loan_due_date: u64, // Due date for the loan repayment
        loan_amount: u64, // Principal amount of the loan
        user_address: address,  // Address of the user who took the loan
    }
    
    // Type that represents the platform's loan system:
    public struct LoanPlatform<phantom COIN> has key, store { // Define LoanPlatform struct with a phantom type parameter COIN and key, store abilities
        id: UID, // Unique identifier for the loan platform
        inner: ID, // Internal ID for the platform
        balance: Bag, // Bag containing the platform's balance
        interest_rate: u64, // Interest rate applied to loans
        mutex: Mutex // Mutex for reentrancy protection
    }

    public struct LoanPlatformCap has key { // Define LoanPlatformCap struct with key ability
        id: UID, // Unique identifier for the cap
        platform: ID // Internal ID of the associated loan platform
    }

    public struct Protocol has key, store { // Define Protocol struct with key, store abilities
        id: UID, // Unique identifier
        balance: Bag // Bag containing the protocol's balance
    }

    public struct AdminCap has key { // Define AdminCap struct with key ability
        id: UID // Unique identifier
    }

    /// Initialize protocol and admin cap
    public fun init(ctx: &mut TxContext) {
        transfer::share_object(Protocol {
            id: object::new(ctx),
            balance: bag::new(ctx)
        });
        transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
    }

    /// Create a new loan platform.
    public fun new_loan_platform<COIN>(interest_rate: u64, ctx: &mut TxContext) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        transfer::share_object(LoanPlatform<COIN> {
            id: id_,
            inner: inner_,
            balance: bag::new(ctx),
            interest_rate: interest_rate,
            mutex: mutex::new(ctx) // Initialize the mutex
        });
        transfer::transfer(LoanPlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx));
    }

    /// Issue a loan to a user.
    public fun issue_loan<COIN>(
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext
    ): LoanAccount<COIN> {
        mutex::lock(&mut loan_platform.mutex); // Lock the mutex to prevent reentrancy

        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        let total_repayable = value + interest_amount;
        assert!(value >= loan_platform.interest_rate, E_INSUFFICIENT_FUNDS);

        let protocol_fee = coin::split(&mut coin, interest_amount, ctx);
        let protocol_balance = coin::into_balance(protocol_fee);
        let loan_balance = coin::into_balance(coin);

        let protocol_bag = &mut protocol.balance;
        let loan_platform_bag = &mut loan_platform.balance;

        let _name = coin::get_name(coin_metadata);
        let coin_names = string::utf8(b"coins");

        helper_bag(protocol_bag, coin_names, protocol_balance);
        helper_bag(loan_platform_bag, coin_names, loan_balance);

        let id_ = object::new(ctx);
        let inner_ = object::uid_to_address(&id_);
        let loan_account = LoanAccount {
            id: id_,
            inner: inner_,
            loan_date: timestamp_ms(clock),
            last_payment_date: 0,
            loan_due_date: timestamp_ms(clock) + 30 * 24 * 60 * 60 * 1000,
            loan_amount: value,
            user_address: sender(ctx),
        };

        emit("LoanIssued", (loan_account.user_address, loan_account.loan_amount, loan_account.loan_date, loan_account.loan_due_date));

        mutex::unlock(&mut loan_platform.mutex); // Unlock the mutex after critical section
        loan_account
    }

    /// Repay a user's loan.
    public fun repay_loan<COIN>(
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        loan_acc: &mut LoanAccount<COIN>,
        loan_clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        mutex::lock(&mut loan_platform.mutex); // Lock the mutex to prevent reentrancy

        assert!(loan_acc.loan_amount > 0, E_LOAN_ALREADY_REPAID);

        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        let total_repayable = value + interest_amount;
        assert!(value >= loan_platform.interest_rate, E_INSUFFICIENT_FUNDS);

        let protocol_fee = coin::split(&mut coin, interest_amount, ctx);
        let protocol_balance = coin::into_balance(protocol_fee);
        let loan_balance = coin::into_balance(coin);

        let protocol_bag = &mut protocol.balance;
        let loan_platform_bag = &mut loan_platform.balance;

        let _name = coin::get_name(coin_metadata);
        let coin_names = string::utf8(b"coins");

        helper_bag(protocol_bag, coin_names, protocol_balance);
        helper_bag(loan_platform_bag, coin_names, loan_balance);

        loan_acc.loan_amount = 0;
        loan_acc.last_payment_date = timestamp_ms(loan_clock);

        emit("LoanRepaid", (loan_acc.user_address, loan_acc.inner, loan_acc.last_payment_date));

        mutex::unlock(&mut loan_platform.mutex); // Unlock the mutex after critical section
    }

    /// Withdraw protocol fees
    public fun withdraw_fee<COIN>(_: &AdminCap, self: &mut Protocol, coin: String, ctx: &mut TxContext): Coin<COIN> {
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        assert!(balance::value(&balance_) > 0, E_INSUFFICIENT_WITHDRAWAL_FUNDS);
        emit("FeeWithdrawn", (balance::value(&balance_)));
        coin::from_balance(balance_, ctx)
    }

    /// Withdraw loan amount
    public fun withdraw_loan<COIN>(self: &mut LoanPlatform<COIN>, cap: &LoanPlatformCap, coin: String, ctx: &mut TxContext): Coin<COIN> {
        assert!(self.inner == cap.platform, E_INVALID_CAP);
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        assert!(balance::value(&balance_) > 0, E_INSUFFICIENT_WITHDRAWAL_FUNDS);
        emit("LoanWithdrawn", (balance::value(&balance_)));
        coin::from_balance(balance_, ctx)
    }

    // Example accessor functions for fetching user's loan details
    public fun get_loan_date<COIN>(self: &LoanAccount<COIN>): u64 { 
        self.loan_date // Return loan date
    }

    public fun get_loan_id<COIN>(self: &LoanAccount<COIN>): address {
        self.inner // Return loan ID
    }

    public fun get_last_payment_date<COIN>(self: &LoanAccount<COIN>): u64 {
        self.last_payment_date // Return last payment date
    }

    public fun get_loan_due_date<COIN>(self: &LoanAccount<COIN>): u64 {
        self.loan_due_date // Return loan due date
    }

    public fun get_loan_owner<COIN>(self: &LoanAccount<COIN>): address {
        self.user_address // Return loan owner address
    }

    /// Helper function to update bag
    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) {
        if(bag::contains(bag_, coin)) { 
            let coin_value = bag::borrow_mut(bag_, coin); 
            balance::join(coin_value, balance); 
        } else {
            bag::add(bag_, coin, balance); 
        }
    }
}
