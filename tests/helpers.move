#[test_only]
module loan::helpers {
    use sui::test_scenario::{Self as ts, next_tx,Scenario};
    use sui::coin::{Self, Coin, mint_for_testing, CoinMetadata};
    use sui::sui::SUI;
    use sui::balance:: {Self, Balance};
    use sui::test_utils::{assert_eq};
    use std::string::{Self,String};

    use loan::loan::{Self, AdminCap, test_init};
    use loan::usdc::{Self, USDC, init_for_testing_usdc};

    const ADMIN: address = @0xA;
    const TEST_ADDRESS1: address = @0xB;
    const TEST_ADDRESS2: address = @0xC;

    public fun init_test_helper() : Scenario {
       let mut scenario_val = ts::begin(ADMIN);
       let scenario = &mut scenario_val;
 
       {
        test_init(ts::ctx(scenario));
       };
       {
        init_for_testing_usdc(ts::ctx(scenario));
       };
       scenario_val
    }
}