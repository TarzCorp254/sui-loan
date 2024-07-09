module loan::loan {
    use sui::tx_context::{TxContext, sender};
    use sui::coin::{Self, Coin, CoinMetadata};
    use sui::balance::{Self, Balance};
    use sui::bag::{Self, Bag};
    use sui::clock::{Self, Clock, timestamp_ms};
    use std::string::{Self, String};
    use sui::transfer;
    use sui::object;

    /// Error Constants
    const E_INSUFFICIENT_FUNDS: u64 = 1;
    const E_INVALID_CAP: u64 = 4;

    const INTEREST_RATE: u128 = 5;

    // Type that stores user loan data
    public struct LoanAccount<phantom COIN> has key, store {
        id: UID,
        inner: address,
        loan_date: u64,
        last_payment_date: u64,
        loan_due_date: u64,
        loan_amount: u64,
        user_address: address,
    }

    // Type that represents the platform's loan system
    public struct LoanPlatform<phantom COIN> has key, store {
        id: UID,
        inner: address,
        balance: Bag,
        interest_rate: u64,
    }

    public struct LoanPlatformCap has key {
        id: UID,
        platform: address,
    }

    public struct Protocol has key, store {
        id: UID,
        balance: Bag,
    }

    public struct AdminCap has key {
        id: UID,
    }

    public fun init(ctx: &mut TxContext) {
        transfer::share_object(Protocol {
            id: object::new(ctx),
            balance: bag::new(ctx),
        });
        transfer::transfer(AdminCap { id: object::new(ctx) }, sender(ctx));
    }

    public fun has_outstanding_loan<COIN>(loan_acc: &LoanAccount<COIN>): bool {
        loan_acc.loan_amount > 0
    }

    public fun calculate_interest(loan_amount: u64): u64 {
        ((loan_amount as u128) * INTEREST_RATE / 100) as u64
    }

    /// Create a new loan platform.
    public fun new_loan_platform<COIN>(interest_rate: u64, ctx: &mut TxContext) {
        let id = object::new(ctx);
        let inner = object::uid_to_address(&id);
        transfer::share_object(LoanPlatform<COIN> {
            id,
            inner,
            balance: bag::new(ctx),
            interest_rate,
        });
        transfer::transfer(LoanPlatformCap { id: object::new(ctx), platform: inner }, sender(ctx));
    }

    /// Issue a loan to a user.
    public fun issue_loan<COIN>(
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext,
    ): LoanAccount<COIN> {
        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        assert!(value >= loan_platform.interest_rate, E_INSUFFICIENT_FUNDS);

        let protocol_fee = coin::split(&mut coin, interest_amount, ctx);
        let protocol_balance = coin::into_balance(protocol_fee);
        let loan_balance = coin::into_balance(coin);

        let name = coin::get_name(coin_metadata);
        helper_bag(&mut protocol.balance, name, protocol_balance);
        helper_bag(&mut loan_platform.balance, name, loan_balance);

        let id = object::new(ctx);
        let inner = object::uid_to_address(&id);
        LoanAccount {
            id,
            inner,
            loan_date: timestamp_ms(clock),
            last_payment_date: 0,
            loan_due_date: timestamp_ms(clock) + 30 * 24 * 60 * 60 * 1000,
            loan_amount: value,
            user_address: sender(ctx),
        }
    }

    /// Repay a user's loan.
    public fun repay_loan<COIN>(
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        loan_acc: &mut LoanAccount<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
        ctx: &mut TxContext,
    ) {
        let value = coin::value(&coin);
        let interest_amount = ((value as u128) * INTEREST_RATE / 100) as u64;
        assert!(value >= loan_platform.interest_rate, E_INSUFFICIENT_FUNDS);

        let protocol_fee = coin::split(&mut coin, interest_amount, ctx);
        let protocol_balance = coin::into_balance(protocol_fee);
        let loan_balance = coin::into_balance(coin);

        let name = coin::get_name(coin_metadata);
        helper_bag(&mut protocol.balance, name, protocol_balance);
        helper_bag(&mut loan_platform.balance, name, loan_balance);

        loan_acc.loan_amount = 0;
        loan_acc.last_payment_date = timestamp_ms(clock);
    }

    public fun withdraw_fee<COIN>(
        _: &AdminCap,
        self: &mut Protocol,
        coin: String,
        ctx: &mut TxContext,
    ): Coin<COIN> {
        let balance = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        coin::from_balance(balance, ctx)
    }

    public fun withdraw_loan<COIN>(
        self: &mut LoanPlatform<COIN>,
        cap: &LoanPlatformCap,
        coin: String,
        ctx: &mut TxContext,
    ): Coin<COIN> {
        assert!(self.inner == cap.platform, E_INVALID_CAP);
        let balance = bag::remove<String, Balance<COIN>>(&mut self.balance, coin);
        coin::from_balance(balance, ctx)
    }

    /// Accessor functions for fetching user's loan details.
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

    fun helper_bag<COIN>(bag: &mut Bag, coin: String, balance: Balance<COIN>) {
        if bag::contains(bag, coin) {
            let coin_value = bag::borrow_mut(bag, coin);
            balance::join(coin_value, balance);
        } else {
            bag::add(bag, coin, balance);
        }
    }

    // Test-only functions
    #[test_only]
    public fun test_init(ctx: &mut TxContext) {
        init(ctx);
    }

    #[test_only]
    public fun get_protocol_bag_balance<T>(self: &Protocol, coin_metadata: &CoinMetadata<T>): &Balance<T> {
        bag::borrow(&self.balance, coin::get_name(coin_metadata))
    }

    #[test_only]
    public fun get_loan_platform_bag_balance<T>(self: &LoanPlatform<T>, coin_metadata: &CoinMetadata<T>): &Balance<T> {
        bag::borrow(&self.balance, coin::get_name(coin_metadata))
    }

    #[test_only]
    public fun test_issue_loan<COIN>(
        ctx: &mut TxContext,
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
    ) {
        let loan_account = issue_loan(protocol, loan_platform, clock, coin_metadata, coin, ctx);
        assert!(loan_account.loan_amount > 0, E_INSUFFICIENT_FUNDS);
    }

    #[test_only]
    public fun test_repay_loan<COIN>(
        ctx: &mut TxContext,
        protocol: &mut Protocol,
        loan_platform: &mut LoanPlatform<COIN>,
        loan_acc: &mut LoanAccount<COIN>,
        clock: &Clock,
        coin_metadata: &CoinMetadata<COIN>,
        mut coin: Coin<COIN>,
    ) {
        repay_loan(protocol, loan_platform, loan_acc, clock, coin_metadata, coin, ctx);
        assert!(loan_acc.loan_amount == 0, E_INSUFFICIENT_FUNDS);
    }

}
