# PancakeSwapV3StandardModulePrivate Detailed Specification

## Overview

The `PancakeSwapV3StandardModulePrivate` is a comprehensive DeFi module that manages liquidity positions on PancakeSwap V3 for private vaults. This document provides detailed explanations of all functions inherited from `PancakeSwapV3StandardModule` and the private-specific functionality.

## Contract Architecture

### Inheritance Structure
```
PancakeSwapV3StandardModulePrivate
├── PancakeSwapV3StandardModule (abstract base)
│   ├── PausableUpgradeable (OpenZeppelin)
│   ├── ReentrancyGuardUpgradeable (OpenZeppelin)
│   ├── IPancakeSwapV3StandardModule
│   ├── IArrakisLPModule
│   ├── IArrakisLPModuleID
│   └── IERC721Receiver
└── IArrakisLPModulePrivate (private funding interface)
```

### Core Constants & Identifiers
- **Module ID**: `0x44e4a7ca74b28d7356e41d25bca1843604b4c48e4ae397efa6c5a36d3fa7db7a`
  - Calculated as `keccak256(abi.encode("PancakeSwapV3StandardModulePrivate"))`

## Detailed Function Analysis

### 1. Initialization Functions

#### `initialize()`
```solidity
function initialize(
    IOracleWrapper oracle_,
    uint256 init0_,
    uint256 init1_,
    uint24 maxSlippage_,
    address cakeReceiver_,
    uint24 fee_,
    address metaVault_
) external initializer
```

**Purpose**: One-time initialization of the module after deployment via beacon proxy.

**Parameters**:
- `oracle_`: Oracle contract for price validation during rebalancing
- `init0_`, `init1_`: Initial token amounts (at least one must be > 0)
- `maxSlippage_`: Maximum allowed slippage (≤ 10%)
- `cakeReceiver_`: Address to receive manager's CAKE rewards
- `fee_`: PancakeSwap V3 pool fee tier (500, 2500, 10000)
- `metaVault_`: Associated meta vault contract

**Key Operations**:
1. Validates all addresses are non-zero
2. Ensures slippage ≤ 10% (`TEN_PERCENT`)
3. Validates initial amounts
4. Sets up token contracts from meta vault
5. Verifies pool exists for token pair and fee
6. Initializes upgradeable contracts

#### `initializePosition()`
```solidity
function initializePosition(bytes calldata data_) external virtual onlyMetaVault
```

**Purpose**: Placeholder for position initialization logic (left over tokens remain on module).

### 2. Liquidity Management Functions

#### `rebalance()`
```solidity
function rebalance(RebalanceParams calldata params_) external nonReentrant whenNotPaused onlyManager
```

**Purpose**: Core function for rebalancing liquidity positions, swapping tokens, and managing portfolio.

**Parameters Structure** (`RebalanceParams`):
```solidity
struct RebalanceParams {
    ModifyPosition[] decreasePositions;  // Positions to decrease/close
    ModifyPosition[] increasePositions;  // Positions to increase
    SwapPayload swapPayload;            // Token swap configuration
    MintParams[] mintParams;            // New positions to mint
    uint256 minBurn0;                   // Minimum token0 to burn
    uint256 minBurn1;                   // Minimum token1 to burn
    uint256 minDeposit0;                // Minimum token0 to deposit
    uint256 minDeposit1;                // Minimum token1 to deposit
}
```

**Detailed Process**:

1. **Decrease Positions Phase**:
   - Unstakes NFTs from MasterChef V3
   - Decreases liquidity proportionally
   - Collects tokens and fees
   - Burns NFTs if proportion = 100%
   - Distributes manager fees
   - Validates minimum burn amounts

2. **Token Swap Phase** (if `swapPayload.amountIn > 0`):
   - Validates expected return against oracle price
   - Approves tokens to router
   - Executes swap via external router
   - Validates slippage protection
   - Resets approvals

3. **Increase Positions Phase**:
   - Adds liquidity to existing positions
   - Collects fees during the process
   - Stakes NFTs back to MasterChef V3
   - Handles CAKE rewards

4. **Mint New Positions Phase**:
   - Creates new liquidity positions
   - Stakes new NFTs in MasterChef V3
   - Tracks new token IDs

**Security Features**:
- Router address validation (prevents malicious routers)
- Slippage protection on swaps
- Manager fee distribution
- Reentrancy protection

#### `withdraw()`
```solidity
function withdraw(
    address receiver_,
    uint256 proportion_
) public virtual nonReentrant onlyMetaVault returns (uint256 amount0, uint256 amount1)
```

**Purpose**: Withdraws tokens from the module proportionally.

**Process**:
1. Validates receiver and proportion (0 < proportion ≤ BASE)
2. Calculates proportional left-over tokens
3. Decreases liquidity from all positions proportionally
4. Collects and distributes fees
5. Handles CAKE rewards
6. Transfers tokens to receiver

### 3. Private Funding Function

#### `fund()` - Private Module Specific
```solidity
function fund(
    address depositor_,
    uint256 amount0_,
    uint256 amount1_
) external payable onlyMetaVault whenNotPaused nonReentrant
```

**Purpose**: Exclusive function for private vault funding, bypassing public minting process.

**Validation**:
- At least one amount must be > 0
- Native coin (ETH) deposits rejected
- Only meta vault can call

**Process**:
1. Validates input parameters
2. Transfers token0 from depositor (if amount0_ > 0)
3. Transfers token1 from depositor (if amount1_ > 0)
4. Tokens remain on module for subsequent rebalancing

### 4. Fee & Reward Management

#### `withdrawManagerBalance()`
```solidity
function withdrawManagerBalance() public nonReentrant whenNotPaused returns (uint256 amount0, uint256 amount1)
```

**Purpose**: Withdraws accumulated manager fees from all positions.

**Process**:
1. Collects fees from all token IDs
2. Harvests CAKE rewards from MasterChef V3
3. Calculates manager portion of fees and CAKE
4. Transfers manager fees to manager address

#### `setManagerFeePIPS()`
```solidity
function setManagerFeePIPS(uint256 newFeePIPS_) external onlyManager whenNotPaused
```

**Purpose**: Updates manager fee percentage (in PIPS - points in percent).

**Process**:
1. Validates new fee ≤ 10000 PIPS (100%)
2. Withdraws current manager balance
3. Updates fee structure

#### `claimRewards()`
```solidity
function claimRewards(address receiver_) external onlyMetaVaultOwner nonReentrant whenNotPaused
```

**Purpose**: Claims CAKE rewards for vault owner (after manager fees).

**Process**:
1. Harvests CAKE from all staked positions
2. Allocates manager portion to manager balance
3. Transfers remaining CAKE to receiver

#### `claimManager()`
```solidity
function claimManager() public nonReentrant whenNotPaused
```

**Purpose**: Claims accumulated CAKE rewards for the manager.

**Process**:
1. Harvests CAKE from all positions
2. Adds manager portion to accumulated balance
3. Transfers total manager balance to cake receiver

#### `setReceiver()`
```solidity
function setReceiver(address newReceiver_) external whenNotPaused
```

**Purpose**: Updates the address that receives manager's CAKE rewards.

**Authorization**: Only manager owner can update

### 5. Access Control & Security

#### `approve()`
```solidity
function approve(
    address spender_,
    address[] calldata tokens_,
    uint256[] calldata amounts_
) external nonReentrant whenNotPaused onlyMetaVaultOwner
```

**Purpose**: Approves tokens to external contracts for RFQ (Request for Quote) systems.

**Security**: 
- Native coin approvals rejected
- Only meta vault owner can approve
- Used for advanced trading strategies

#### `pause()` / `unpause()`
```solidity
function pause() external whenNotPaused onlyGuardian
function unpause() external whenPaused onlyGuardian
```

**Purpose**: Emergency pause/unpause functionality controlled by guardian.

### 6. View Functions

#### Position & State Queries
- `tokenIds()`: Returns array of managed NFT token IDs
- `maxSlippage()`: Current maximum slippage setting
- `cakeReceiver()`: Address receiving manager CAKE rewards
- `pool()`: PancakeSwap V3 pool address
- `oracle()`: Oracle contract address

#### Balance Queries
- `totalUnderlying()`: Total token amounts in all positions at current price
- `totalUnderlyingAtPrice(uint160 priceX96_)`: Total amounts at specified price
- `managerBalance0()` / `managerBalance1()`: Unclaimed manager fees
- `cakeManagerBalance()`: Unclaimed manager CAKE rewards

#### Validation
- `validateRebalance(IOracleWrapper oracle_, uint24 maxDeviation_)`: Validates pool price against oracle within deviation limits

### 7. Internal Helper Functions

#### Position Management
- `_decreaseLiquidity()`: Handles position decrease and fee collection
- `_increaseLiquidity()`: Handles position increase and staking
- `_collectFees()`: Collects fees without changing liquidity
- `_mint()`: Creates new liquidity positions
- `_unstake()`: Removes NFT from MasterChef V3

#### Price & Validation
- `_checkMinReturn()`: Validates swap returns against oracle prices
- `_totalUnderlying()`: Calculates total underlying at given price
- `_managerBalance()`: Calculates manager fee balances
- `_getPosition()`: Retrieves position details from NFT

## Key Data Structures

### ModifyPosition
```solidity
struct ModifyPosition {
    uint256 tokenId;     // NFT token ID to modify
    uint256 proportion;  // Proportion to modify (BASE = 100%)
}
```

### SwapPayload
```solidity
struct SwapPayload {
    bytes payload;              // Encoded swap call data
    address router;             // Router contract address
    uint256 amountIn;          // Input token amount
    uint256 expectedMinReturn; // Minimum expected output
    bool zeroForOne;           // Swap direction
}
```

### MintReturnValues
```solidity
struct MintReturnValues {
    uint256 amount0;  // Token0 amount used
    uint256 amount1;  // Token1 amount used
    uint256 fee0;     // Token0 fees collected
    uint256 fee1;     // Token1 fees collected
    uint256 cakeCo;   // CAKE rewards collected
}
```

## Integration Points

### PancakeSwap V3 Integration
- **NFT Position Manager**: Creates, modifies, and manages liquidity positions
- **Pool Interface**: Interacts with specific trading pools
- **MasterChef V3**: Stakes NFTs for additional CAKE rewards

### Arrakis Ecosystem Integration
- **Meta Vault**: Primary integration point for vault operations
- **Guardian System**: Provides security and emergency controls
- **Oracle System**: Price validation and MEV protection
- **Manager System**: Fee collection and strategy execution

### External Protocol Integration
- **Router Integration**: Supports various DEX routers for token swaps
- **Permit2**: Advanced approval system integration
- **Oracle Wrapper**: Standardized price feed interface

## Security Considerations

### Access Control
- Multi-layer permission system (Guardian, Manager, MetaVault Owner)
- Function-specific access controls
- Emergency pause functionality

### MEV Protection
- Oracle-based price validation
- Slippage protection on all operations
- Maximum deviation checks

### Reentrancy Protection
- All state-changing functions protected
- Proper approval management
- Safe token transfer patterns

### Input Validation
- Comprehensive parameter validation
- Non-zero address checks
- Range validation for percentages and amounts

This module represents a sophisticated DeFi infrastructure component designed for professional liquidity management with multiple layers of security and extensive integration capabilities.