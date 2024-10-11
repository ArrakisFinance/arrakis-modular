# IUniV4StandardModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IUniV4StandardModule.sol)


## Functions
### initialize

initialize function to delegate call onced the beacon proxy is deployed,
for initializing the uniswap v4 standard module.

*this function will deposit fund as left over on poolManager.*


```solidity
function initialize(
    uint256 init0_,
    uint256 init1_,
    bool isInversed_,
    PoolKey calldata poolKey_,
    IOracleWrapper oracle_,
    uint24 maxSlippage_,
    address metaVault_
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`init0_`|`uint256`|initial amount of token0 to provide to uniswap standard module.|
|`init1_`|`uint256`|initial amount of token1 to provide to valantis module.|
|`isInversed_`|`bool`|boolean to check if the poolKey's currencies pair are inversed, compared to the module's tokens pair.|
|`poolKey_`|`PoolKey`|pool key of the uniswap v4 pool that will be used by the module.|
|`oracle_`|`IOracleWrapper`|address of the oracle used by the uniswap v4 standard module.|
|`maxSlippage_`|`uint24`|allowed to manager for rebalancing the inventory using swap.|
|`metaVault_`|`address`|address of the meta vault|


### setPool

function used to set the pool for the module.


```solidity
function setPool(
    PoolKey calldata poolKey_,
    LiquidityRange[] calldata liquidityRanges_,
    SwapPayload calldata swapPayload_
) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`poolKey_`|`PoolKey`|pool key of the uniswap v4 pool that will be used by the module.|
|`liquidityRanges_`|`LiquidityRange[]`|list of liquidity ranges to be used by the module on the new pool.|
|`swapPayload_`|`SwapPayload`|swap payload to be used during rebalance.|


### rebalance

function used to rebalance the inventory of the module.


```solidity
function rebalance(
    LiquidityRange[] calldata liquidityRanges_,
    SwapPayload memory swapPayload_
)
    external
    returns (
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`liquidityRanges_`|`LiquidityRange[]`|list of liquidity ranges to be used by the module.|
|`swapPayload_`|`SwapPayload`|swap payload to be used during rebalance.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Minted`|`uint256`|amount of token0 minted.|
|`amount1Minted`|`uint256`|amount of token1 minted.|
|`amount0Burned`|`uint256`|amount of token0 burned.|
|`amount1Burned`|`uint256`|amount of token1 burned.|


### getRanges

function used to get the list of active ranges.


```solidity
function getRanges() external view returns (Range[] memory ranges);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`ranges`|`Range[]`|active ranges|


### poolKey

function used to get the pool's key of the module.


```solidity
function poolKey()
    external
    view
    returns (
        Currency currency0,
        Currency currency1,
        uint24 fee,
        int24 tickSpacing,
        IHooks hooks
    );
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`currency0`|`Currency`|currency0 of the pool.|
|`currency1`|`Currency`|currency1 of the pool.|
|`fee`|`uint24`|fee of the pool.|
|`tickSpacing`|`int24`|tick spacing of the pool.|
|`hooks`|`IHooks`|hooks of the pool.|


### poolManager

function used to get the uniswap v4 pool manager.


```solidity
function poolManager() external view returns (IPoolManager);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`IPoolManager`|poolManager return the pool manager.|


### isInversed

function used to know if the poolKey's currencies pair are inversed.


```solidity
function isInversed() external view returns (bool);
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
### LogSetPool

```solidity
event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
```

### LogRebalance

```solidity
event LogRebalance(
    LiquidityRange[] liquidityRanges,
    uint256 amount0Minted,
    uint256 amount1Minted,
    uint256 amount0Burned,
    uint256 amount1Burned
);
```

## Errors
### Currency0DtToken0

```solidity
error Currency0DtToken0(address currency0, address token0);
```

### Currency1DtToken1

```solidity
error Currency1DtToken1(address currency1, address token1);
```

### Currency1DtToken0

```solidity
error Currency1DtToken0(address currency1, address token0);
```

### Currency0DtToken1

```solidity
error Currency0DtToken1(address currency0, address token1);
```

### SqrtPriceZero

```solidity
error SqrtPriceZero();
```

### OnlyPoolManager

```solidity
error OnlyPoolManager();
```

### OnlyModuleCaller

```solidity
error OnlyModuleCaller();
```

### InvalidCurrencyDelta

```solidity
error InvalidCurrencyDelta();
```

### RangeShouldBeActive

```solidity
error RangeShouldBeActive(int24 tickLower, int24 tickUpper);
```

### OverBurning

```solidity
error OverBurning();
```

### TicksMisordered

```solidity
error TicksMisordered(int24 tickLower, int24 tickUpper);
```

### TickLowerOutOfBounds

```solidity
error TickLowerOutOfBounds(int24 tickLower);
```

### TickUpperOutOfBounds

```solidity
error TickUpperOutOfBounds(int24 tickUpper);
```

### OnlyMetaVaultOrManager

```solidity
error OnlyMetaVaultOrManager();
```

### SamePool

```solidity
error SamePool();
```

### NoRemoveLiquidityHooks

```solidity
error NoRemoveLiquidityHooks();
```

### OverMaxDeviation

```solidity
error OverMaxDeviation();
```

### CallBackNotSupported

```solidity
error CallBackNotSupported();
```

### NativeCoinCannotBeToken1

```solidity
error NativeCoinCannotBeToken1();
```

### MaxSlippageGtTenPercent

```solidity
error MaxSlippageGtTenPercent();
```

### ExpectedMinReturnTooLow

```solidity
error ExpectedMinReturnTooLow();
```

### WrongRouter

```solidity
error WrongRouter();
```

### SlippageTooHigh

```solidity
error SlippageTooHigh();
```

## Structs
### Range

```solidity
struct Range {
    int24 tickLower;
    int24 tickUpper;
}
```

### LiquidityRange

```solidity
struct LiquidityRange {
    Range range;
    int128 liquidity;
}
```

