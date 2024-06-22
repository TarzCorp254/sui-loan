#[allow(lint(self_transfer))]
module loan::loan {
    use sui::tx_context::{ sender};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::bag::{Self, Bag};
    use sui::clock::{Self, Clock, timestamp_ms};
    use std::string::{Self, String};

    /// Error Constants ///
    const EInsufficientFunds: u64 = 1; // Insufficient funds to process the loan
    const EInvalidCap: u64 = 4; // Invalid loan cap

    const INTEREST_RATE: u128 = 5;

    // Type that stores user loan data:
    public struct LoanAccount<phantom COIN> has key {
        id: UID,
        inner: address,
        loan_date: u64,
        last_payment_date: u64,
        loan_due_date: u64,
        loan_amount: u64,
        user_address: address,
    }
    

    // Type that represents the platform's loan system:
    public struct LoanPlatform<phantom COIN> has key, store {
        id: UID,
        inner: ID,
        balance: Bag,
        interest_rate: u64
    }

    public struct LoanPlatformCap has key {
        id: UID,
        platform: ID
    }

    public struct Protocol has key, store {
        id: UID,
        balance: Bag
    }

    public struct AdminCap has key {
        id: UID
    }

    // public fun init(ctx: &mut TxContext) {
    //     transfer::share_object(Protocol {
    //         id: object::new(ctx),
    //         balance: bag::new(ctx)
    //     });
    //     transfer::transfer(AdminCap{id: object::new(ctx)}, sender(ctx));
    // }

    /// Create a new loan platform.
    public fun new_loan_platform<COIN>(interest_rate:u64, ctx: &mut TxContext) {
        let id_ = object::new(ctx);
        let inner_ = object::uid_to_inner(&id_);
        transfer::share_object(LoanPlatform<COIN> {
            id: id_,
            inner: inner_,
            balance: bag::new(ctx),
            interest_rate: interest_rate
        });
        transfer::transfer(LoanPlatformCap{id: object::new(ctx), platform: inner_}, sender(ctx));
    }

    // Issue a loan to a user.
    public fun issue_loan<COIN>(
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext
    ) : LoanAccount<COIN> {
        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        let _total_repayable = value + interest_amount;
        assert!(value >= loan_platform.interest_rate, EInsufficientFunds);

        let protocol_fee = interest_amount;
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx);
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
            loan_date: clock::timestamp_ms(clock),
            last_payment_date: 0,
            loan_due_date: clock::timestamp_ms(clock) + 30 * 24 * 60 * 60 * 1000, // 30 days from loan date
            loan_amount: value,
            user_address: sender(ctx),
        };
        loan_account
    }

    // Repay a user's loan.
    public fun repay_loan<COIN>(
        protocol:&mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        loan_acc: &mut LoanAccount<COIN>,
        c: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext
    ) {
        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        let _total_repayable = value + interest_amount;
        assert!(value >= loan_platform.interest_rate, EInsufficientFunds);

        let protocol_fee = interest_amount;
        let protocol_fee = coin::split(&mut coin, protocol_fee, ctx);
        let protocol_balance = coin::into_balance(protocol_fee);
        let loan_balance = coin::into_balance(coin);

        let protocol_bag = &mut protocol.balance;
        let loan_platform_bag = &mut loan_platform.balance;

        let _name = coin::get_name(coin_metadata);
        let coin_names = string::utf8(b"coins");

        helper_bag(protocol_bag, coin_names, protocol_balance);
        helper_bag(loan_platform_bag, coin_names, loan_balance);

        loan_acc.loan_amount = 0;
        loan_acc.last_payment_date = timestamp_ms(c);
    }

    public fun withdraw_fee<COIN>(_:&AdminCap, self: &mut Protocol, coin: String, ctx: &mut TxContext) : Coin<COIN> {
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    public fun withdraw_loan<COIN>(self: &mut LoanPlatform<COIN>, cap: &LoanPlatformCap, coin: String, ctx: &mut TxContext) : Coin<COIN> {
        assert!(self.inner == cap.platform, EInvalidCap);
        let balance_ = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        let coin_ = coin::from_balance(balance_, ctx);
        coin_
    }

    // Example accessor function for fetching user's loan details
    public fun get_loan_date<COIN>(self: &LoanAccount<COIN>): u64 {
        self.loan_date
    }
    public fun get_loan_id<COIN>(self: &LoanAccount<COIN>): address {
        self.inner
    }
    public fun get_last_payment_date<COIN>(self: &LoanAccount<COIN>): u64 {
        self.last_payment_date
    }
    public fun get_loan_due_date<COIN>(self: &LoanAccount<COIN>): u64 {
        self.loan_due_date
    }
    public fun get_loan_owner<COIN>(self: &LoanAccount<COIN>): address {
        self.user_address
    }

    fun helper_bag<COIN>(bag_: &mut Bag, coin: String, balance: Balance<COIN>) {
        if(bag::contains(bag_, coin)) { 
            let coin_value = bag::borrow_mut(bag_, coin);
            balance::join(coin_value, balance);
        }
        else {
            bag::add(bag_, coin, balance);
        };
    }
}
