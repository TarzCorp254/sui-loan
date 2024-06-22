INTRODUCTION

This module implements a loan system that allows users to borrow and repay loans with interest. It supports creating loan platforms, issuing loans, and managing loan repayments. The module uses Sui Move and includes structures and functions to handle loans, interest calculations, and interactions with the loan platform.

KEY STRUCTURES

LoanAccount

Stores individual loan details for users:
- id: Unique identifier of the loan.
- inner: Address of the loan account.
- loan_date: Timestamp of when the loan was issued.
- last_payment_date: Timestamp of the last repayment.
- loan_due_date: Due date for the loan repayment.
- loan_amount: The principal amount of the loan.
- user_address: Address of the user who took the  loan.

LoanPlatform

Represents the platform's loan system:
- id: Unique identifier of the loan platform.
- inner: Internal ID for the platform.
- balance: A Bag containing the platform's balance.
- interest_rate: Interest rate applied to loans.

LoanPlatformCap

Ensures that only authorized entities can manage the loan platform:
- id: Unique identifier of the cap.
- platform: Internal ID of the associated loan platform.

Protocol

Manages the protocol's balance:
- id: Unique identifier.
- balance: A Bag containing the protocol's balance.

AdminCap

Ensures only admins can withdraw fees:
- id: Unique identifier.

CORE FUNCTIONS

new_loan_platform

Creates a new loan platform with a specified interest rate.
- Parameters: `interest_rate`, `ctx`
- Returns: Transfers LoanPlatformCap to the caller.

issue_loan

Issues a loan to a user.
- Parameters: `protocol`, `loan_platform`, `clock`, `coin_metadata`, `coin`, `ctx`
- Returns: `LoanAccount`

repay_loan

Repays a user's loan.
- Parameters: `protocol`, `loan_platform`, `loan_acc`, `clock`, `coin_metadata`, `coin`, `ctx`

withdraw_fee

Withdraws protocol fees.
- Parameters: `admin_cap`, `protocol`, `coin`, `ctx`
- Returns: `Coin`

withdraw_loan

Withdraws loan balance from the platform.
- Parameters: `loan_platform`, `cap`, `coin`, `ctx`
- Returns: `Coin`

Error Constants

- EInsufficientFunds (1): Insufficient funds to process the loan.
- EInvalidCap (4): Invalid loan cap.

Interest Rate

- INTEREST_RATE: 5%

HELPER FUNCTIONS

helper_bag

Helper function to manage balances within a Bag.
- Parameters: `bag`, `coin`, `balance`

ACCESOR FUNCTIONS

get_loan_date

Fetches the loan issuance date.
- Parameters: `loan_account`
- Returns: `u64`

get_loan_id

Fetches the loan account ID.
- Parameters: `loan_account`
- Returns: `address`

get_last_payment_date

Fetches the last repayment date.
- Parameters: `loan_account`
- Returns: `u64`

get_loan_due_date

Fetches the loan due date.
- Parameters: `loan_account`
- Returns: `u64`

get_loan_owner

Fetches the loan owner address.
- Parameters: `loan_account`
- Returns: `address`

SUMMARY

This module allows the creation and management of loan platforms, issuance and repayment of loans, and administration of platform balances. It includes detailed error handling, interest rate application, and accessor functions to retrieve loan details. The provided functions ensure secure and efficient loan management within the Sui Move ecosystem.