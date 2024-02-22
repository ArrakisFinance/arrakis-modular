# ArrakisPublicVaultWethRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/ArrakisPublicVaultWethRouter.sol)

**Inherits:**
[ArrakisPublicVaultRouter](/src/ArrakisPublicVaultRouter.sol/contract.ArrakisPublicVaultRouter.md), [IArrakisPublicVaultWethRouter](/src/interfaces/IArrakisPublicVaultWethRouter.sol/interface.IArrakisPublicVaultWethRouter.md)


## State Variables
### weth

```solidity
IWETH9 public immutable weth;
```


## Functions
### constructor


```solidity
constructor(address nativeToken_, address permit2_, address swapper_, address owner_, address factory_, address weth_)
    ArrakisPublicVaultRouter(nativeToken_, permit2_, swapper_, owner_, factory_);
```

### wrapAndAddLiquidity

wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function wrapAndAddLiquidity(AddLiquidityData memory params_)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.vault)
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
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.addData.vault)
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


### removeLiquidityAndUnwrap

removeLiquidityAndUnwrap removes liquidity from vault and burns LP tokens and then wrap weth
to send it to receiver.

*hack to get rid of stack too depth*


```solidity
function removeLiquidityAndUnwrap(RemoveLiquidityData memory params_)
    external
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.vault)
    returns (uint256 amount0, uint256 amount1);
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


### wrapAndAddLiquidityPermit2

wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)


```solidity
function wrapAndAddLiquidityPermit2(AddLiquidityPermit2Data memory params_)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.addData.vault)
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
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.swapAndAddData.addData.vault)
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


### removeLiquidityPermit2AndUnwrap

removeLiquidityPermit2AndUnwrap removes liquidity from vault and burns LP tokens and then wrap weth
to send it to receiver.

*hack to get rid of stack too depth*


```solidity
function removeLiquidityPermit2AndUnwrap(RemoveLiquidityPermit2Data memory params_)
    external
    nonReentrant
    whenNotPaused
    onlyPublicVault(params_.removeData.vault)
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


### _permit2AddLengthOne


```solidity
function _permit2AddLengthOne(
    AddLiquidityPermit2Data memory params_,
    address token0_,
    address token1_,
    uint256 amount0_,
    uint256 amount1_
) internal;
```

### _permit2SwapAndAddLengthOne


```solidity
function _permit2SwapAndAddLengthOne(SwapAndAddPermit2Data memory params_, address token0_, address token1_) internal;
```

