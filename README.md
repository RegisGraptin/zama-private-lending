# Confidential layer for lending protocol

This project introduces a confidentiality layer between users and lending protocols such as AAVE. Its purpose is to obfuscate the lending amounts of individual users.

## Overview

Traditionally, when users supply tokens to AAVE, as USDC, they receive aTokens representing their lending positions. However, to preserve privacy, users cannot directly receive aTokens proportional to their supplied amount, as this would reveal their individual balances.

To address this, we introduce a confidentiality layer that enables users to supply liquidity while keeping their balances hidden. User deposits are encrypted and stored privately, and operations are grouped to prevent exposure of individual amounts.

This is achieved by first wrapping the tokens using Zama’s `ConfidentialERC20Wrapped` contract. This contract can wrap any ERC20 token and enables encryption of user balances. Users can unwrap and retrieve their available (i.e., not currently lent) liquidity at any time.

Once balances are hidden, users can choose to provide liquidity to AAVE by submitting encrypted amounts. However, to sent the amount on AAVE, we require to have the plain-text amount. To bridge this gap without compromising privacy, we employ a batching and iteration mechanism.

During each iteration, we are grouping the supply/withdrawal operation from all the users. This is done by computing in a variable the amount of token we need to transfer. A positive amount indicates a supply to AAVE, while a negative one indicates a withdrawal. This operation can be executed once we have reached a predefined timestamp. Notice that different mechanisms could have been used as a threshold parameter of users or even a combination of both.

This iteration mechanism preserves user balance confidentiality by only revealing the aggregated operation across multiple users, without exposing any individual user's action.

The confidential layer is responsible for holding both the original tokens and the aToken representations from AAVE. Lending rewards will continue to be distributed proportionally based on each user's encrypted contribution.

To illustrate how the protocol works, you can take a look at the diagram below. A user begins by wrapping some tokens, such as USDC. By wrapping them, the Confidential layer encrypts and stores the user’s token amount. The user can then choose to provide liquidity to AAVE by creating a transaction, which will be executed in the next iteration. During this iteration, based on user actions, the protocol determines whether it needs to supply or withdraw USDC according to the net operations.

To unwrap the tokens, the user must ensure there are sufficient available funds in the protocol. If there aren’t, the user will first need to request a withdrawal operation to remove liquidity from AAVE, before being able to unwrap the tokens.

![User Workflow](./workflow.png)

Well / Not Well / More time

## Protocol Limitations

In our current design, we have use a timestamp to wait enough operation. However, it would be maybe more interesting to wait a number of operations and a number of time.

- In a case where all participants want to maximize their yield, if all of them provide liquidity, we can then guess that they provide all the liquidity available, meaning all of their tokens. Currently, we do not have incentive mechanism to reward users by providing only a part of their liquidity to protect other user balance.

- In a scenario where a user wants to provide a large amount of liquidity, it could potentially leak their balance. For example, if one user provides one million USDC while others only contribute a thousand, anyone monitoring the amount sent to AAVE could infer the contributor’s identity based on the transaction size. This risk can be mitigated by ensuring a large number of users contribute to provide liquidity, while broken down the liquidity acros multiple rounds. This approach helps obfuscate individual contributions and prevents leakage of user balances. But to work efficiently, it may required incentivise mechanism.

- One limitation of the current protocol is that we do not handle situations where AAVE lacks sufficient liquidity. If AAVE does not have enough available liquidity, we must wait until enough liquidity is available before proceeding with the transaction.

- At the moment, our protocol can handle only one ERC20 at a time. One improvment could be to integrate a ERC-1155 approach, allowing multiple token representation.

## Well / Not Well

TODO:

- How to compute efficiently the lending reward.
  > tracking individual user positions and interest accrual while preserving amount confidentiality.

In order to handle lending we are going to rely on snapshot.

On each round, we are going to update the lending position of the protocol while computing the reward for the other users

# Improvment

- Could have created a dedicated ERC20 for the aWrapToken lended.
