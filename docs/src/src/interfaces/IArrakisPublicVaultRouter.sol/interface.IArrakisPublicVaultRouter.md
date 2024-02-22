# IArrakisPublicVaultRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisPublicVaultRouter.sol)


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

addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function addLiquidity(AddLiquidityData memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityData`|AddLiquidityData struct containing data for adding liquidity|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|


### swapAndAddLiquidity

swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor


```solidity
function swapAndAddLiquidity(SwapAndAddData memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived, uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddData`|SwapAndAddData struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### removeLiquidity

removeLiquidity removes liquidity from vault and burns LP tokens


```solidity
function removeLiquidity(RemoveLiquidityData memory params_) external returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`RemoveLiquidityData`|RemoveLiquidityData struct containing data for withdrawals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|actual amount of token0 transferred to receiver for burning `burnAmount`|
|`amount1`|`uint256`|actual amount of token1 transferred to receiver for burning `burnAmount`|


### addLiquidityPermit2

addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)


```solidity
function addLiquidityPermit2(AddLiquidityPermit2Data memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityPermit2Data`|AddLiquidityPermit2Data struct containing data for adding liquidity|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|


### swapAndAddLiquidityPermit2

swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor


```solidity
function swapAndAddLiquidityPermit2(SwapAndAddPermit2Data memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived, uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddPermit2Data`|SwapAndAddPermit2Data struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### removeLiquidityPermit2

removeLiquidityPermit2 removes liquidity from vault and burns LP tokens


```solidity
function removeLiquidityPermit2(RemoveLiquidityPermit2Data memory params_)
    external
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`RemoveLiquidityPermit2Data`|RemoveLiquidityPermit2Data struct containing data for withdrawals|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|actual amount of token0 transferred to receiver for burning `burnAmount`|
|`amount1`|`uint256`|actual amount of token1 transferred to receiver for burning `burnAmount`|


### wrapAndAddLiquidity

wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function wrapAndAddLiquidity(AddLiquidityData memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityData`|AddLiquidityData struct containing data for adding liquidity|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|


### wrapAndSwapAndAddLiquidity

wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor


```solidity
function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived, uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddData`|SwapAndAddData struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### wrapAndAddLiquidityPermit2

wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)


```solidity
function wrapAndAddLiquidityPermit2(AddLiquidityPermit2Data memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`AddLiquidityPermit2Data`|AddLiquidityPermit2Data struct containing data for adding liquidity|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|


### wrapAndSwapAndAddLiquidityPermit2

wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor


```solidity
function wrapAndSwapAndAddLiquidityPermit2(SwapAndAddPermit2Data memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived, uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddPermit2Data`|SwapAndAddPermit2Data struct containing data for swap|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 transferred from msg.sender to mint `mintAmount`|
|`amount1`|`uint256`|amount of token1 transferred from msg.sender to mint `mintAmount`|
|`sharesReceived`|`uint256`|amount of public vault tokens transferred to `receiver`|
|`amount0Diff`|`uint256`|token0 balance difference post swap|
|`amount1Diff`|`uint256`|token1 balance difference post swap|


### getMintAmounts

getMintAmounts used to get the shares we can mint from some max amounts.


```solidity
function getMintAmounts(address vault_, uint256 maxAmount0_, uint256 maxAmount1_)
    external
    view
    returns (uint256 shareToMint, uint256 amount0ToDeposit, uint256 amount1ToDeposit);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|meta vault address.|
|`maxAmount0_`|`uint256`|maximum amount of token0 user want to contribute.|
|`maxAmount1_`|`uint256`|maximum amount of token1 user want to contribute.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shareToMint`|`uint256`|maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.|
|`amount0ToDeposit`|`uint256`|amount of token0 user should deposit into the vault for minting 'shareToMint'.|
|`amount1ToDeposit`|`uint256`|amount of token1 user should deposit into the vault for minting 'shareToMint'.|


## Events
### Swapped
event emitted when a swap happen before depositing.


```solidity
event Swapped(bool zeroForOne, uint256 amount0Diff, uint256 amount1Diff, uint256 amountOutSwap);
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

### NoNativeTokenAndValueNotZero

```solidity
error NoNativeTokenAndValueNotZero();
```

### OnlyPublicVault

```solidity
error OnlyPublicVault();
```

### EmptyMaxAmounts

```solidity
error EmptyMaxAmounts();
```

### NothingToMint

```solidity
error NothingToMint();
```

### NothingToBurn

```solidity
error NothingToBurn();
```

### BelowMinAmounts

```solidity
error BelowMinAmounts();
```

### SwapCallFailed

```solidity
error SwapCallFailed();
```

### ReceivedBelowMinimum

```solidity
error ReceivedBelowMinimum();
```

### LengthMismatch

```solidity
error LengthMismatch();
```

### NoNativeToken

```solidity
error NoNativeToken();
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

### MsgValueDTMaxAmount

```solidity
error MsgValueDTMaxAmount();
```

### NoWethToken

```solidity
error NoWethToken();
```

### Permit2WethNotAuthorized

```solidity
error Permit2WethNotAuthorized();
```

