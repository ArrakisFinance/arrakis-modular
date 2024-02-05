# IValantisSOTModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/interfaces/IValantisSOTModule.sol)


## Functions
### swap

function to swap token0->token1 or token1->token0 and then change
inventory.


```solidity
function swap(bool zeroForOne_, uint256 expectedMinReturn_, uint256 amountIn_, address router_, bytes calldata payload_)
    external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`zeroForOne_`|`bool`|boolean if true token0->token1, if false token1->token0.|
|`expectedMinReturn_`|`uint256`|minimum amount of tokenOut expected.|
|`amountIn_`|`uint256`|amount of tokenIn used during swap.|
|`router_`|`address`|address of routerSwapExecutor.|
|`payload_`|`bytes`|data payload used for swapping.|


### setManager

function used to set new manager

*setting a manager different than the module,
will make the module unusable.
let's make it not implemented for now*


```solidity
function setManager(address newManager_) external;
```

### setPriceBounds

fucntion used to set range on valantis AMM


```solidity
function setPriceBounds(
    uint128 _sqrtPriceLowX96,
    uint128 _sqrtPriceHighX96,
    uint160 _expectedSqrtSpotPriceUpperX96,
    uint160 _expectedSqrtSpotPriceLowerX96
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_sqrtPriceLowX96`|`uint128`|lower bound of the range in sqrt price.|
|`_sqrtPriceHighX96`|`uint128`|upper bound of the range in sqrt price.|
|`_expectedSqrtSpotPriceUpperX96`|`uint160`|expected lower limit of current spot price (to prevent sandwich attack and manipulation).|
|`_expectedSqrtSpotPriceLowerX96`|`uint160`|expected upper limit of current spot price (to prevent sandwich attack and manipulation).|


### pool

function used to get the valantis sot pool.


```solidity
function pool() external view returns (ISovereignPool);
```

### alm

function used to get the valantis sot alm/ liquidity module.


```solidity
function alm() external view returns (ISOT);
```

### oracle

function used to get the oracle that
will be used to proctect rebalances.


```solidity
function oracle() external view returns (IOracleWrapper);
```

### maxSlippage

function used to get the max slippage that
can occur during swap rebalance.


```solidity
function maxSlippage() external view returns (uint24);
```

## Events
### LogSwap

```solidity
event LogSwap(uint256 oldBalance0, uint256 oldBalance1, uint256 newBalance0, uint256 newBalance1);
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

### TotalSupplyZero

```solidity
error TotalSupplyZero();
```

### Actual0DifferentExpected

```solidity
error Actual0DifferentExpected(uint256 actual0, uint256 expected0);
```

### Actual1DifferentExpected

```solidity
error Actual1DifferentExpected(uint256 actual1, uint256 expected1);
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

### SlippageTooHigh

```solidity
error SlippageTooHigh();
```

### RouterTakeTooMuchTokenIn

```solidity
error RouterTakeTooMuchTokenIn();
```

### NotDepositedAllToken0

```solidity
error NotDepositedAllToken0();
```

### NotDepositedAllToken1

```solidity
error NotDepositedAllToken1();
```

