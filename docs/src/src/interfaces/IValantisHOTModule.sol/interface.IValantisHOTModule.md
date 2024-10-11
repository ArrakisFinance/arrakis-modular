# IValantisHOTModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IValantisHOTModule.sol)


## Functions
### initialize

initialize function to delegate call onced the beacon proxy is deployed,
for initializing the valantis module.
who can call deposit and withdraw functions.


```solidity
function initialize(
    address pool_,
    uint256 init0_,
    uint256 init1_,
    uint24 maxSlippage_,
    address metaVault_
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`pool_`|`address`|address of the valantis sovereign pool.|
|`init0_`|`uint256`|initial amount of token0 to provide to valantis module.|
|`init1_`|`uint256`|initial amount of token1 to provide to valantis module.|
|`maxSlippage_`|`uint24`|allowed to manager for rebalancing the inventory using swap.|
|`metaVault_`|`address`|address of the meta vault|


### setALMAndManagerFees

set HOT and initialize manager fees function.


```solidity
function setALMAndManagerFees(
    address alm_,
    address oracle_
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`alm_`|`address`|address of the valantis HOT ALM.|
|`oracle_`|`address`|address of the oracle used by the valantis HOT module.|


### setPriceBounds

fucntion used to set range on valantis AMM


```solidity
function setPriceBounds(
    uint160 _sqrtPriceLowX96,
    uint160 _sqrtPriceHighX96,
    uint160 _expectedSqrtSpotPriceLowerX96,
    uint160 _expectedSqrtSpotPriceUpperX96
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sqrtPriceLowX96`|`uint160`|lower bound of the range in sqrt price.|
|`_sqrtPriceHighX96`|`uint160`|upper bound of the range in sqrt price.|
|`_expectedSqrtSpotPriceLowerX96`|`uint160`|expected upper limit of current spot price (to prevent sandwich attack and manipulation).|
|`_expectedSqrtSpotPriceUpperX96`|`uint160`|expected lower limit of current spot price (to prevent sandwich attack and manipulation).|


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
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`zeroForOne_`|`bool`|boolean if true token0->token1, if false token1->token0.|
|`expectedMinReturn_`|`uint256`|minimum amount of tokenOut expected.|
|`amountIn_`|`uint256`|amount of tokenIn used during swap.|
|`router_`|`address`| address of smart contract that will execute swap.|
|`expectedSqrtSpotPriceUpperX96_`|`uint160`|upper bound of current price.|
|`expectedSqrtSpotPriceLowerX96_`|`uint160`|lower bound of current price.|
|`payload_`|`bytes`|data payload used for swapping.|


### pool

function used to get the valantis hot pool.


```solidity
function pool() external view returns (ISovereignPool);
```

### alm

function used to get the valantis hot alm/ liquidity module.


```solidity
function alm() external view returns (IHOT);
```

### maxSlippage

function used to get the max slippage that
can occur during swap rebalance.


```solidity
function maxSlippage() external view returns (uint24);
```

### oracle

function used to get the oracle that
will be used to proctect rebalances.


```solidity
function oracle() external view returns (IOracleWrapper);
```

## Events
### LogSetALM

```solidity
event LogSetALM(address alm);
```

### LogInitializePosition

```solidity
event LogInitializePosition(uint256 amount0, uint256 amount1);
```

### LogSwap

```solidity
event LogSwap(
    uint256 oldBalance0,
    uint256 oldBalance1,
    uint256 newBalance0,
    uint256 newBalance1
);
```

## Errors
### NoNativeToken



```solidity
error NoNativeToken();
```

### OnlyPool

```solidity
error OnlyPool(address caller, address pool);
```

### AmountsZeros

```solidity
error AmountsZeros();
```

### NotImplemented

```solidity
error NotImplemented();
```

### ExpectedMinReturnTooLow

```solidity
error ExpectedMinReturnTooLow();
```

### MaxSlippageGtTenPercent

```solidity
error MaxSlippageGtTenPercent();
```

### NotDepositedAllToken0

```solidity
error NotDepositedAllToken0();
```

### NotDepositedAllToken1

```solidity
error NotDepositedAllToken1();
```

### OnlyMetaVaultOwner

```solidity
error OnlyMetaVaultOwner();
```

### ALMAlreadySet

```solidity
error ALMAlreadySet();
```

### SlippageTooHigh

```solidity
error SlippageTooHigh();
```

### NotEnoughToken0

```solidity
error NotEnoughToken0();
```

### NotEnoughToken1

```solidity
error NotEnoughToken1();
```

### SwapCallFailed

```solidity
error SwapCallFailed();
```

### OverMaxDeviation

```solidity
error OverMaxDeviation();
```

### WrongRouter

```solidity
error WrongRouter();
```

