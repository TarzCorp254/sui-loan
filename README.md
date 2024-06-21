Introduction

The loan module enables users to borrow and repay loans with interest. It supports creating loan platforms, issuing loans, and managing repayments within the Sui Move framework.

Key Structures

- LoanAccount: Stores individual loan details including loan amount, dates, and user address.
- LoanPlatform: Represents the loan system platform, containing balance and interest rate.
- LoanPlatformCap: Ensures authorized management of the loan platform.
- Protocol: Manages the protocol's balance.
- AdminCap: Ensures only admins can withdraw fees.

Core Functions

- new_loan_platform: Creates a new loan platform with a specified interest rate.
- issue_loan: Issues a loan to a user and returns a LoanAccount.
- repay_loan: Processes the repayment of a loan.
- withdraw_fee: Allows admins to withdraw protocol fees.
- withdraw_loan: Withdraws loan balance from the platform.

Error Constants

- EInsufficientFunds (1): Triggered when there are insufficient funds to process the loan.
- EInvalidCap (4): Triggered by an invalid loan cap.

Interest Rate

- Set at 5%

Helper Functions

- helper_bag: Manages balances within a Bag.

Accessor Functions
- Fetch various loan details such as issuance date, loan ID, last payment date, due date, and owner address.

Summary

The module facilitates secure and efficient loan management by allowing the creation and administration of loan platforms, issuing loans, and handling repayments. It includes error handling and interest rate management, ensuring a robust loan system within the Sui Move ecosystem.