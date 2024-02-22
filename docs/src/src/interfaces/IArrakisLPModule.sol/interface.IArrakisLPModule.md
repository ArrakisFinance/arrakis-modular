# IArrakisLPModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisLPModule.sol)

**Author:**
Arrakis Finance

Module interfaces, modules are implementing differents strategies that an
arrakis module can use.


## Functions
### pause

function used to pause the module.

*only callable by guardian*


```solidity
function pause() external;
```

### unpause

function used to unpause the module.

*only callable by guardian*


```solidity
function unpause() external;
```

### withdraw

function used by metaVault to withdraw tokens from the strategy.


```solidity
function withdraw(address receiver_, uint256 proportion_) external returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver_`|`address`|address that will receive tokens.|
|`proportion_`|`uint256`|number of share needed to be withdrawn.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 withdrawn.|
|`amount1`|`uint256`|amount of token1 withdrawn.|


### withdrawManagerBalance

function used by metaVault or manager to get manager fees.


```solidity
function withdrawManagerBalance() external returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 sent to manager.|
|`amount1`|`uint256`|amount of token1 sent to manager.|


### setManagerFeePIPS

function used to set manager fees.


```solidity
function setManagerFeePIPS(uint256 newFeePIPS_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFeePIPS_`|`uint256`|new fee that will be applied.|


### metaVault

function used to get metaVault as IArrakisMetaVault.


```solidity
function metaVault() external view returns (IArrakisMetaVault);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IArrakisMetaVault`|metaVault that implement IArrakisMetaVault.|


### guardian

function used to get the address that can pause the module.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|guardian address of the pauser.|


### managerBalance0

function used to get manager token0 balance.

*amount of fees in token0 that manager have not taken yet.*


```solidity
function managerBalance0() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managerBalance0 amount of token0 that manager earned.|


### managerBalance1

function used to get manager token1 balance.

*amount of fees in token1 that manager have not taken yet.*


```solidity
function managerBalance1() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managerBalance1 amount of token1 that manager earned.|


### managerFeePIPS

function used to get manager fees.


```solidity
function managerFeePIPS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managerFeePIPS amount of token1 that manager earned.|


### token0

function used to get token0 as IERC20Metadata.


```solidity
function token0() external view returns (IERC20Metadata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20Metadata`|token0 as IERC20Metadata.|


### token1

function used to get token0 as IERC20Metadata.


```solidity
function token1() external view returns (IERC20Metadata);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IERC20Metadata`|token1 as IERC20Metadata.|


### getInits

function used to get the initial amounts needed to open a position.


```solidity
function getInits() external view returns (uint256 init0, uint256 init1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`init0`|`uint256`|the amount of token0 needed to open a position.|
|`init1`|`uint256`|the amount of token1 needed to open a position.|


### totalUnderlying

function used to get the amount of token0 and token1 sitting
on the position.


```solidity
function totalUnderlying() external view returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position.|
|`amount1`|`uint256`|the amount of token1 sitting on the position.|


### totalUnderlyingAtPrice

function used to get the amounts of token0 and token1 sitting
on the position for a specific price.


```solidity
function totalUnderlyingAtPrice(uint160 priceX96_) external view returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceX96_`|`uint160`|price at which we want to simulate our tokens composition|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position for priceX96.|
|`amount1`|`uint256`|the amount of token1 sitting on the position for priceX96.|


### validateRebalance

function used to validate if module state is not manipulated
before rebalance.


```solidity
function validateRebalance(IOracleWrapper oracle_, uint24 maxDeviation_) external view;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oracle_`|`IOracleWrapper`|oracle that will used to check internal state.|
|`maxDeviation_`|`uint24`|maximum deviation allowed.|


## Events
### LogWithdraw
Event describing a withdrawal of participation by an user inside this module.

*withdraw action can be indexed by receiver.*


```solidity
event LogWithdraw(address indexed receiver, uint256 proportion, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver`|`address`|address that will receive the tokens withdrawn.|
|`proportion`|`uint256`|percentage of the current position that user want to withdraw.|
|`amount0`|`uint256`|amount of token0 send to "receiver" due to withdraw action.|
|`amount1`|`uint256`|amount of token1 send to "receiver" due to withdraw action.|

### LogWithdrawManagerBalance
Event describing a manager fee withdrawal.


```solidity
event LogWithdrawManagerBalance(address manager, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`manager`|`address`|address of the manager that will fees earned due to his fund management.|
|`amount0`|`uint256`|amount of token0 that manager has earned and will be transfered.|
|`amount1`|`uint256`|amount of token1 that manager has earned and will be transfered.|

### LogSetManagerFeePIPS
Event describing manager set his fees.


```solidity
event LogSetManagerFeePIPS(uint256 oldFee, uint256 newFee);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldFee`|`uint256`|fees share that have been taken by manager.|
|`newFee`|`uint256`|fees share that have been taken by manager.|

## Errors
### AddressZero
*triggered when an address that should not
be zero is equal to address zero.*


```solidity
error AddressZero();
```

### OnlyMetaVault
*triggered when the caller is different than
the metaVault that own this module.*


```solidity
error OnlyMetaVault(address caller, address metaVault);
```

### OnlyManager
*triggered when the caller is different than
the manager defined by the metaVault.*


```solidity
error OnlyManager(address caller, address manager);
```

### ProportionZero
*triggered if proportion of minting or burning is
zero.*


```solidity
error ProportionZero();
```

### ProportionGtPIPS
*triggered if during withdraw more than 100% of the
position.*


```solidity
error ProportionGtPIPS();
```

### NewFeesGtPIPS
*triggered when manager want to set his more
earned by the position than 100% of fees earned.*


```solidity
error NewFeesGtPIPS(uint256 newFees);
```

### SameManagerFee
*triggered when manager is setting the same fees
that already active.*


```solidity
error SameManagerFee();
```

### InitsAreZeros
*triggered when inits values are zeros.*


```solidity
error InitsAreZeros();
```

### OnlyGuardian
*triggered when pause/unpaused function is
called by someone else than guardian.*


```solidity
error OnlyGuardian();
```

