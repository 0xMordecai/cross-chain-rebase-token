# Cross-chain Rebase Token

1. A protocol that allows users to deposit into a vault and in return, receive rebase tokens that represent their underlying balance.

2. The rebase token's balanceof function is dynamic to show the changing balance with time.

3. The protocol sets an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the vault.

We will set the interest rate such that the global interest rate can only decrease over time to incentivize early adopters.

A user deposits into the vault smart contract, the vault contract calls the rebase token and the rebase token mints rebase tokens for the user equal to the amount that they deposited. The user's interest rate is set based on the global interest rate.

Let's say the global interest rate is 0.05% per day and a user deposits. They are given an interest rate of 0.05%. Then, let's say the global interest rate drops to 0.04%. A second user makes a deposit. They inherit the global interest rate of 0.04%, but the first user maintains their interest rate of 0.05%.
