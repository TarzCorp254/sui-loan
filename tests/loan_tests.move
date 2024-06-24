#[test_only]
module loan::loan_test {
    use sui::test_scenario::{Self as ts, next_tx, Scenario};
    use sui::coin::{Self, Coin, CoinMetadata, mint_for_testing};
    use sui::sui::SUI;
    use sui::tx_context::TxContext;
    use sui::object::UID;
    use sui::test_utils::{assert_eq};
    use sui::clock::{Self, Clock};
    use sui::transfer::{Self};

    use std::vector;
    use std::string::{Self, String};

    use loan::loan::{Self, AdminCap, LoanAccount, LoanPlatform, LoanPlatformCap, Protocol, test_init};
    use loan::helpers::{Self, init_test_helper};
    use loan::usdc::{Self, USDC};

    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;

    #[test]
    public fun test_new_loan_platform() {

        let mut scenario_test = init_test_helper();
        let scenario = &mut scenario_test;

        next_tx(scenario, TEST_ADDRESS1);
        {
            let rate: u64 = 5;
            loan::new_loan_platform<USDC>(rate, ts::ctx(scenario));     
        };
        next_tx(scenario, TEST_ADDRESS1);
        {
            let mut protocol = ts::take_shared<Protocol>(scenario);
            let mut loan_platform = ts::take_shared<LoanPlatform<USDC>>(scenario);
            let clock = clock::create_for_testing(ts::ctx(scenario));
            let usdc_metadata = ts::take_immutable<CoinMetadata<USDC>>(scenario);
            let mut usdc_coin = mint_for_testing<USDC>(1000, ts::ctx(scenario));

            let account = loan::issue_loan<USDC>(
                &mut protocol,
                &mut loan_platform,
                &clock,
                &usdc_metadata,
                usdc_coin,
                ts::ctx(scenario)
            );

            transfer::public_transfer(account, TEST_ADDRESS1);
            ts::return_immutable(usdc_metadata);
            ts::return_shared(protocol);
            ts::return_shared(loan_platform);
            clock::share_for_testing(clock);

        };






        ts::end(scenario_test);
}

}