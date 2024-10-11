# BunkerModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/modules/BunkerModule.sol)

**Inherits:**
[IArrakisLPModule](/src/interfaces/IArrakisLPModule.sol/interface.IArrakisLPModule.md), [IArrakisLPModuleID](/src/interfaces/IArrakisLPModuleID.sol/interface.IArrakisLPModuleID.md), [IBunkerModule](/src/interfaces/IBunkerModule.sol/interface.IBunkerModule.md), PausableUpgradeable, ReentrancyGuardUpgradeable


## State Variables
### id

```solidity
bytes32 public constant id =
    0xce98d8396fff0b5125f78c5c5878c5c82596417dec23d9d52e0ed2377d14b9b8;
```


### metaVault

```solidity
IArrakisMetaVault public metaVault;
```


### token0

```solidity
IERC20Metadata public token0;
```


### token1

```solidity
IERC20Metadata public token1;
```


### _guardian

```solidity
address internal immutable _guardian;
```


## Functions
### onlyMetaVault


```solidity
modifier onlyMetaVault();
```

### onlyGuardian


```solidity
modifier onlyGuardian();
```

### constructor


```solidity
constructor(address guardian_);
```

### initialize

initialize function to delegate call onced the beacon proxy is deployed,
for initializing the bunker module.


```solidity
function initialize(address metaVault_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metaVault_`|`address`|address of the meta vault.|


### pause

function used to pause the module.

*only callable by guardian*


```solidity
function pause() external onlyGuardian;
```

### unpause

function used to unpause the module.

*only callable by guardian*


```solidity
function unpause() external onlyGuardian;
```

### initializePosition


```solidity
function initializePosition(bytes calldata) external;
```

### withdraw

function used by metaVault to withdraw tokens from the strategy.


```solidity
function withdraw(
    address receiver_,
    uint256 proportion_
)
    public
    virtual
    onlyMetaVault
    nonReentrant
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver_`|`address`|address that will receive tokens.|
|`proportion_`|`uint256`|the proportion of the total position that need to be withdrawn.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 withdrawn.|
|`amount1`|`uint256`|amount of token1 withdrawn.|


### withdrawManagerBalance

function used by metaVault or manager to get manager fees.


```solidity
function withdrawManagerBalance()
    external
    returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 sent to manager.|
|`amount1`|`uint256`|amount of token1 sent to manager.|


### setManagerFeePIPS

function used to set manager fees.


```solidity
function setManagerFeePIPS(uint256) external;
```

### managerBalance0

function used to get manager token0 balance.

*amount of fees in token0 that manager have not taken yet.*


```solidity
function managerBalance0() external view returns (uint256 fees0);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees0`|`uint256`|amount of token0 that manager earned.|


### managerBalance1

function used to get manager token1 balance.

*amount of fees in token1 that manager have not taken yet.*


```solidity
function managerBalance1() external view returns (uint256 fees1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`fees1`|`uint256`|amount of token1 that manager earned.|


### validateRebalance

function used to validate if module state is not manipulated
before rebalance.


```solidity
function validateRebalance(IOracleWrapper, uint24) external view;
```

### totalUnderlyingAtPrice

function used to get the amounts of token0 and token1 sitting
on the position for a specific price.


```solidity
function totalUnderlyingAtPrice(uint160)
    external
    view
    returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position for priceX96.|
|`amount1`|`uint256`|the amount of token1 sitting on the position for priceX96.|


### totalUnderlying

function used to get the amount of token0 and token1 sitting
on the position.


```solidity
function totalUnderlying()
    external
    view
    returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position.|
|`amount1`|`uint256`|the amount of token1 sitting on the position.|


### getInits

function used to get the initial amounts needed to open a position.


```solidity
function getInits()
    external
    view
    returns (uint256 init0, uint256 init1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`init0`|`uint256`|the amount of token0 needed to open a position.|
|`init1`|`uint256`|the amount of token1 needed to open a position.|


### managerFeePIPS

function used to get manager fees.


```solidity
function managerFeePIPS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managerFeePIPS amount of token1 that manager earned.|


### guardian

function used to get the address that can pause the module.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|guardian address of the pauser.|


