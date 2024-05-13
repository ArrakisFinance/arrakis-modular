# ValantisModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/abstracts/ValantisHOTModule.sol)

**Inherits:**
[IArrakisLPModule](/src/interfaces/IArrakisLPModule.sol/interface.IArrakisLPModule.md), [IValantisHOTModule](/src/interfaces/IValantisHOTModule.sol/interface.IValantisHOTModule.md), PausableUpgradeable, ReentrancyGuardUpgradeable

*BeaconProxy be careful for changing implementation with upgrade.*


## State Variables
### metaVault

```solidity
IArrakisMetaVault public metaVault;
```


### pool

```solidity
ISovereignPool public pool;
```


### alm

```solidity
IHOT public alm;
```


### token0

```solidity
IERC20Metadata public token0;
```


### token1

```solidity
IERC20Metadata public token1;
```


### maxSlippage
*should we change it to mutable state variable,
and settable by who?*


```solidity
uint24 public maxSlippage;
```


### oracle

```solidity
IOracleWrapper public oracle;
```


### _init0

```solidity
uint256 internal _init0;
```


### _init1

```solidity
uint256 internal _init1;
```


### _guardian

```solidity
address internal _guardian;
```


## Functions
### onlyMetaVault


```solidity
modifier onlyMetaVault();
```

### onlyManager


```solidity
modifier onlyManager();
```

### onlyGuardian


```solidity
modifier onlyGuardian();
```

### initialize


```solidity
function initialize(
    address metaVault_,
    address pool_,
    address alm_,
    uint256 init0_,
    uint256 init1_,
    uint24 maxSlippage_,
    address oracle_,
    address guardian_
) external initializer;
```

### pause

function used to pause the module.

*only callable by guardian*


```solidity
function pause() external whenNotPaused onlyGuardian;
```

### unpause

function used to unpause the module.

*only callable by guardian*


```solidity
function unpause() external whenPaused onlyGuardian;
```

### withdraw

function used by metaVault to withdraw tokens from the strategy.


```solidity
function withdraw(address receiver_, uint256 proportion_)
    external
    onlyMetaVault
    whenNotPaused
    nonReentrant
    returns (uint256 amount0, uint256 amount1);
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
function withdrawManagerBalance() external whenNotPaused nonReentrant returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 sent to manager.|
|`amount1`|`uint256`|amount of token1 sent to manager.|


### setManagerFeePIPS

function used to set manager fees.


```solidity
function setManagerFeePIPS(uint256 newFeePIPS_) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newFeePIPS_`|`uint256`|new fee that will be applied.|


### swap

function to swap token0->token1 or token1->token0 and then change
inventory.


```solidity
function swap(
    bool zeroForOne_,
    uint256 expectedMinReturn_,
    uint256 amountIn_,
    address router_,
    uint160 expectedSqrtSpotPriceUpperX96_,
    uint160 expectedSqrtSpotPriceLowerX96_,
    bytes calldata payload_
) external onlyManager whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`zeroForOne_`|`bool`|boolean if true token0->token1, if false token1->token0.|
|`expectedMinReturn_`|`uint256`|minimum amount of tokenOut expected.|
|`amountIn_`|`uint256`|amount of tokenIn used during swap.|
|`router_`|`address`|address of routerSwapExecutor.|
|`expectedSqrtSpotPriceUpperX96_`|`uint160`|upper bound of current price.|
|`expectedSqrtSpotPriceLowerX96_`|`uint160`|lower bound of current price.|
|`payload_`|`bytes`|data payload used for swapping.|


### setPriceBounds

fucntion used to set range on valantis AMM


```solidity
function setPriceBounds(
    uint128 sqrtPriceLowX96_,
    uint128 sqrtPriceHighX96_,
    uint160 expectedSqrtSpotPriceUpperX96_,
    uint160 expectedSqrtSpotPriceLowerX96_
) external onlyManager;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`sqrtPriceLowX96_`|`uint128`|lower bound of the range in sqrt price.|
|`sqrtPriceHighX96_`|`uint128`|upper bound of the range in sqrt price.|
|`expectedSqrtSpotPriceUpperX96_`|`uint160`|expected lower limit of current spot price (to prevent sandwich attack and manipulation).|
|`expectedSqrtSpotPriceLowerX96_`|`uint160`|expected upper limit of current spot price (to prevent sandwich attack and manipulation).|


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


### managerFeePIPS

function used to get manager fees.


```solidity
function managerFeePIPS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|managerFeePIPS amount of token1 that manager earned.|


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
|`oracle_`|`IOracleWrapper`|onchain oracle to check the current amm price against.|
|`maxDeviation_`|`uint24`|maximum deviation tolerated by management.|


### _checkMinReturn


```solidity
function _checkMinReturn(
    bool zeroForOne_,
    uint256 expectedMinReturn_,
    uint256 amountIn_,
    uint8 decimals0_,
    uint8 decimals1_
) internal view;
```

### guardian

function used to get the address that can pause the module.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|guardian address of the pauser.|


