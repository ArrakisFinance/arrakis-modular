# IArrakisPrivateVaultRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IArrakisPrivateVaultRouter.sol)


## Functions
### pause

function used to pause the router.

*only callable by owner*


```solidity
function pause() external;
```

### unpause

function used to unpause the router.

*only callable by owner*


```solidity
function unpause() external;
```

### addLiquidity

addLiquidity adds liquidity to meta vault of interest (mints L tokens)


```solidity
function addLiquidity(AddLiquidityData memory params_)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityData`|AddLiquidityData struct containing data for adding liquidity|


### swapAndAddLiquidity

swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor


```solidity
function swapAndAddLiquidity(SwapAndAddData memory params_)
    external
    payable
    returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddData`|SwapAndAddData struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### addLiquidityPermit2

addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)


```solidity
function addLiquidityPermit2(AddLiquidityPermit2Data memory params_)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityPermit2Data`|AddLiquidityPermit2Data struct containing data for adding liquidity|


### swapAndAddLiquidityPermit2

swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor


```solidity
function swapAndAddLiquidityPermit2(
    SwapAndAddPermit2Data memory params_
)
    external
    payable
    returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddPermit2Data`|SwapAndAddPermit2Data struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### wrapAndAddLiquidity

wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function wrapAndAddLiquidity(AddLiquidityData memory params_)
    external
    payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityData`|AddLiquidityData struct containing data for adding liquidity|


### wrapAndSwapAndAddLiquidity

wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor


```solidity
function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
    external
    payable
    returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddData`|SwapAndAddData struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### wrapAndAddLiquidityPermit2

wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)


```solidity
function wrapAndAddLiquidityPermit2(
    AddLiquidityPermit2Data memory params_
) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityPermit2Data`|AddLiquidityPermit2Data struct containing data for adding liquidity|


### wrapAndSwapAndAddLiquidityPermit2

wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor


```solidity
function wrapAndSwapAndAddLiquidityPermit2(
    SwapAndAddPermit2Data memory params_
)
    external
    payable
    returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddPermit2Data`|SwapAndAddPermit2Data struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


## Events
### Swapped
event emitted when a swap happen before depositing.


```solidity
event Swapped(
    bool zeroForOne,
    uint256 amount0Diff,
    uint256 amount1Diff,
    uint256 amountOutSwap
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`zeroForOne`|`bool`|boolean indicating if we are swap token0 to token1 or the inverse.|
|`amount0Diff`|`uint256`|amount of token0 get or consumed by the swap.|
|`amount1Diff`|`uint256`|amount of token1 get or consumed by the swap.|
|`amountOutSwap`|`uint256`|minimum amount of tokens out wanted after swap.|

## Errors
### AddressZero

```solidity
error AddressZero();
```

### NotEnoughNativeTokenSent

```solidity
error NotEnoughNativeTokenSent();
```

### OnlyPrivateVault

```solidity
error OnlyPrivateVault();
```

### OnlyDepositor

```solidity
error OnlyDepositor();
```

### RouterIsNotDepositor

```solidity
error RouterIsNotDepositor();
```

### EmptyAmounts

```solidity
error EmptyAmounts();
```

### LengthMismatch

```solidity
error LengthMismatch();
```

### Deposit0

```solidity
error Deposit0();
```

### Deposit1

```solidity
error Deposit1();
```

### MsgValueZero

```solidity
error MsgValueZero();
```

### NativeTokenNotSupported

```solidity
error NativeTokenNotSupported();
```

### MsgValueDTAmount

```solidity
error MsgValueDTAmount();
```

### NoWethToken

```solidity
error NoWethToken();
```

### Permit2WethNotAuthorized

```solidity
error Permit2WethNotAuthorized();
```

