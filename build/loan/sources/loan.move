#[allow(lint(self_transfer))] // Allow self-transfer lint
module loan::loan { // Define the module loan::loan
    use sui::tx_context::{sender}; // Import the sender function from sui::tx_context
    use sui::coin::{Self, Coin, CoinMetadata}; // Import Coin, CoinMetadata from sui::coin
    use sui::balance::{Self, Balance}; // Import Balance from sui::balance
    use sui::bag::{Self, Bag}; // Import Bag from sui::bag
    use sui::clock::{Self, Clock, timestamp_ms}; // Import Clock, timestamp_ms from sui::clock
    use std::string::{Self, String}; // Import String from std::string

    /// Error Constants ///
    const EInsufficientFunds: u64 = 1; // Error code for insufficient funds
    const EInvalidCap: u64 = 4; // Error code for invalid loan cap

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
        interest_rate: u64 // Interest rate applied to loans
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

    // public fun init(ctx: &mut TxContext) {
    //     transfer::share_object(Protocol {
    //         id: object::new(ctx),
    //         balance: bag::new(ctx)
    //     });
    //     transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
    // }
    // Initialize protocol and admin cap (commented out)

    /// Create a new loan platform.
    public fun new_loan_platform<COIN>(interest_rate:u64, ctx: &mut TxContext) { // Function to create a new loan platform
        let id_ = object::new(ctx); // Create a new unique identifier
        let inner_ = object::uid_to_inner(&id_); // Convert UID to inner ID
        transfer::share_object(LoanPlatform<COIN> { // Share LoanPlatform object
            id: id_, // Set ID
            inner: inner_, // Set inner ID
            balance: bag::new(ctx), // Initialize balance as a new bag
            interest_rate: interest_rate // Set interest rate
        });
        transfer::transfer(LoanPlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx)); // Transfer LoanPlatformCap to the caller
    }

    // Issue a loan to a user.
    public fun issue_loan<COIN>( // Function to issue a loan
        protocol: &mut Protocol, // Reference to the protocol
        loan_platform: &mut LoanPlatform<COIN>, // Reference to the loan platform
        clock: &Clock, // Reference to the clock
        coin_metadata: &CoinMetadata<COIN>, // Reference to the coin metadata
        mut coin: Coin<COIN>, // Mutable reference to the coin
        ctx: &mut TxContext // Reference to the transaction context
    ) : LoanAccount<COIN> { // Returns a LoanAccount
        let value = coin::value(&coin); // Get the value of the coin
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64; // Calculate the interest amount
        let _total_repayable = value + interest_amount; // Calculate the total repayable amount
        assert!(value >= loan_platform.interest_rate, EInsufficientFunds); // Check if value is sufficient

        let protocol_fee = interest_amount; // Set protocol fee to interest amount
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx); // Split the coin for the protocol fee
        let protocol_balance = coin::into_balance(protocol_fee); // Convert protocol fee to balance
        let loan_balance = coin::into_balance(coin); // Convert remaining coin to balance

        let protocol_bag = &mut protocol.balance; // Get protocol's balance bag
        let loan_platform_bag = &mut loan_platform.balance; // Get loan platform's balance bag

        let _name = coin::get_name(coin_metadata); // Get the coin name
        let coin_names = string::utf8(b"coins"); // Convert byte string to UTF-8 string

        helper_bag(protocol_bag, coin_names, protocol_balance); // Update protocol bag with protocol balance
        helper_bag(loan_platform_bag, coin_names, loan_balance); // Update loan platform bag with loan balance

        let id_ = object::new(ctx); // Create a new unique identifier
        let inner_ = object::uid_to_address(&id_);  // Convert UID to address
        let loan_account = LoanAccount { // Create a new LoanAccount
            id: id_, // Set ID
            inner: inner_, // Set inner address
            loan_date: clock::timestamp_ms(clock), // Set loan date to current timestamp
            last_payment_date: 0, // Initialize last payment date to 0
            loan_due_date: clock::timestamp_ms(clock) + 30 * 24 * 60 * 60 * 1000, // Set loan due date to 30 days from loan date
            loan_amount: value, // Set loan amount to coin value
            user_address: sender(ctx), // Set user address to sender
        };
        loan_account // Return the LoanAccount
    }

    // Repay a user's loan.
    public fun repay_loan<COIN>( // Function to repay a loan
        protocol:&mut Protocol, // Reference to the protocol
        loan_platform: &mut LoanPlatform<COIN>, // Reference to the loan platform
        loan_acc: &mut LoanAccount<COIN>, // Reference to the loan account
        c: &Clock, // Reference to the clock
        coin_metadata: &CoinMetadata<COIN>, // Reference to the coin metadata
        mut coin: Coin<COIN>, // Mutable reference to the coin
        ctx: &mut TxContext // Reference to the transaction context
    ) {
        let value = coin::value(&coin); // Get the value of the coin
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64; // Calculate the interest amount
        let _total_repayable = value + interest_amount; // Calculate the total repayable amount
        assert!(value >= loan_platform.interest_rate, EInsufficientFunds); // Check if value is sufficient

        let protocol_fee = interest_amount; // Set protocol fee to interest amount
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx); // Split the coin for the protocol fee
        let protocol_balance = coin::into_balance(protocol_fee); // Convert protocol fee to balance
        let loan_balance = coin::into_balance(coin); // Convert remaining coin to balance

        let protocol_bag = &mut protocol.balance; // Get protocol's balance bag
        let loan_platform_bag = &mut loan_platform.balance; // Get loan platform's balance bag

        let _name = coin::get_name(coin_metadata); // Get the coin name
        let coin_names = string::utf8(b"coins"); // Convert byte string to UTF-8 string

        helper_bag(protocol_bag, coin_names, protocol_balance); // Update protocol bag with protocol balance
        helper_bag(loan_platform_bag, coin_names, loan_balance); // Update loan platform bag with loan balance

        loan_acc.loan_amount = 0; // Set loan amount to 0
        loan_acc.last_payment_date = timestamp_ms(c); // Set last payment date to current timestamp
    }

    public fun withdraw_fee<COIN>(_:&AdminCap, self: &mut Protocol, coin: String, ctx: &mut TxContext) : Coin<COIN> { // Function to withdraw protocol fees
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin); // Remove balance from protocol bag
        let coin_ = coin::from_balance(balance_, ctx); // Convert balance to coin
        coin_ // Return the coin
    }

    public fun withdraw_loan<COIN>(self: &mut LoanPlatform<COIN>, cap: &LoanPlatformCap, coin: String, ctx: &mut TxContext) : Coin<COIN> { // Function to withdraw loan amount
        assert!(self.inner == cap.platform, EInvalidCap); // Check if cap is valid
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin); // Remove balance from loan platform bag
        let coin_ = coin::from_balance(balance_, ctx); // Convert balance to coin
        coin_ // Return the coin
    }

    // Example accessor function for fetching user's loan details
    public fun get_loan_date<COIN>(self: &LoanAccount<COIN>): u64 { // Get loan date
        self.loan_date // Return loan date
    }
    public fun get_loan_id<COIN>(self: &LoanAccount<COIN>): address { // Get loan ID
        self.inner // Return loan ID
    }
    public fun get_last_payment_date<COIN>(self: &LoanAccount<COIN>): u64 { // Get last payment date
        self.last_payment_date // Return last payment date
    }
    public fun get_loan_due_date<COIN>(self: &LoanAccount<COIN>): u64 { // Get loan due date
        self.loan_due_date // Return loan due date
    }
    public fun get_loan_owner<COIN>(self: &LoanAccount<COIN>): address { // Get loan owner address
        self.user_address // Return loan owner address
    }

    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) { // Helper function to update bag
        if(bag::contains(bag_, coin)) {  // Check if bag contains the coin
            let coin_value = bag::borrow_mut(bag_, coin); // Borrow mutable reference to the coin balance in the bag
            balance::join(coin_value, balance); // Join the balances
        }
        else { // If bag does not contain the coin
            bag::add(bag_, coin, balance); // Add new coin balance to the bag
        };
    }
}
