# PancakeSwapV3StandardModule Invariant Testing Guide

## Overview

This document outlines the key invariants and actors for implementing an Actor-Based Invariant Testing Suite for the PancakeSwapV3StandardModule abstract smart contract. The module manages liquidity positions on PancakeSwap V3 through a private vault architecture.

## Key Actors

### Primary Actors

1. **MetaVault** - The main vault contract that orchestrates user deposits/withdrawals
2. **Manager** - Strategy executor who performs rebalancing operations and sets fees
3. **MetaVaultOwner** - Owner of the metavault with administrative privileges
4. **Guardian** - Emergency actor who can pause/unpause operations
5. **Users** - End users who interact indirectly through the private vault

### Secondary Actors

6. **CakeReceiver** - Receives the manager's share of CAKE rewards
7. **External Routers** - DEX routers used for token swaps during rebalancing

## Critical Invariants

### 1. Token Accounting Invariants

- **Total Asset Conservation**: `totalUnderlying() == sum(position_values) + leftover_balances`
- **Non-negative Balances**: Token balances should never go below zero
- **Fee Distribution Accuracy**: Manager fees calculated as `fee * managerFeePIPS / PIPS`
- **CAKE Reward Splitting**: CAKE rewards properly split between manager and users according to `managerFeePIPS`

### 2. Position Management Invariants

- **TokenId Ownership**: All tokenIds in `_tokenIds` set must be owned by `masterChefV3` when staked
- **Position Consistency**: Positions must match the correct `token0`, `token1`, and `pool`
- **Liquidity Conservation**: Total liquidity changes should match expected mint/burn amounts
- **Position State Coherence**: Burned positions must be removed from `_tokenIds` set

### 3. Access Control Invariants

- **Manager Exclusivity**: Only `manager` can call `rebalance()` and `setManagerFeePIPS()`
- **MetaVault Exclusivity**: Only `metaVault` can call `withdraw()` and `initializePosition()`
- **Owner Privileges**: Only `metaVaultOwner` can call `claimRewards()` and `approve()`
- **Guardian Powers**: Only `guardian` can `pause()`/`unpause()`

### 4. Slippage & Oracle Protection Invariants

- **Oracle Deviation Bounds**: Pool price vs oracle price deviation ≤ `maxDeviation`
- **Swap Slippage Protection**: Actual swap returns ≥ `expectedMinReturn`
- **Rebalance Bounds**: Burns ≥ `minBurn0/1`, deposits ≥ `minDeposit0/1`
- **Max Slippage Constraint**: `maxSlippage ≤ TEN_PERCENT`

### 5. Fee & Reward Invariants

- **Fee Range Bounds**: `managerFeePIPS ≤ PIPS` (≤ 100%)
- **CAKE Balance Tracking**: `_cakeManagerBalance` accurately reflects manager's pending CAKE
- **Fee Collection Consistency**: Manager fees collected from all fee-generating operations
- **Reward Distribution**: CAKE rewards properly harvested and distributed

### 6. State Transition Invariants

- **Pausability**: Contract can only be paused when not paused, and vice versa
- **Initialization Uniqueness**: `initialize()` can only be called once
- **Approval Hygiene**: Token approvals reset to 0 after operations
- **Native Token Rejection**: `NATIVE_COIN` operations should always revert

### 7. Integration Invariants

- **Staking Consistency**: Positions automatically staked in `masterChefV3` after operations
- **NFT Transfer Safety**: All NFT transfers use `safeTransferFrom()`
- **Router Restrictions**: Swap routers cannot be critical system addresses
- **Pool Parameter Matching**: Mint operations must match existing pool parameters

## Actor-Based Fuzzing Strategy

### Actor Behaviors to Model

- **Manager**: Performs complex rebalancing with random position modifications, swaps, and parameter constraints
- **MetaVaultOwner**: Claims rewards, approves tokens for external contracts
- **Guardian**: Randomly pauses/unpauses during operations to test emergency scenarios
- **MetaVault**: Calls withdraw with various proportions and position states
- **Malicious Actor**: Attempts unauthorized operations and boundary condition attacks

### Fuzzing Focus Areas

1. **Complex Rebalancing Scenarios**: Multiple simultaneous position changes with swaps
2. **Edge Case Proportions**: Withdrawals at 0%, 100%, and values near `BASE`
3. **Oracle Price Manipulation**: Testing behavior near deviation thresholds
4. **Fee Boundary Testing**: Manager fees at 0%, 100%, and intermediate values
5. **Emergency Scenarios**: Operations during paused states
6. **Integration Edge Cases**: Interactions with empty positions, dust amounts, etc.

## Implementation Recommendations

### Test Structure

1. **Actor Contracts**: Create separate contracts for each actor type with appropriate access patterns
2. **State Tracking**: Implement ghost variables to track invariants across operations
3. **Precondition Validation**: Ensure actors can only perform valid operations based on current state
4. **Invariant Assertions**: Add comprehensive invariant checks after each state transition

### Key Test Scenarios

- **Multi-actor Rebalancing**: Manager rebalances while owner claims rewards
- **Emergency Pause**: Guardian pauses during active operations
- **Proportional Withdrawals**: Test edge cases around proportion calculations
- **Fee Collection Timing**: Verify fee accounting across different operation sequences
- **Oracle Protection**: Test behavior when oracle prices deviate significantly

This structure provides a comprehensive foundation for implementing robust invariant testing that covers the module's critical security properties and business logic correctness.