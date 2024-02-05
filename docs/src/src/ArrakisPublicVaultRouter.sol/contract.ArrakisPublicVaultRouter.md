# ArrakisPublicVaultRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/ArrakisPublicVaultRouter.sol)

**Inherits:**
[IArrakisPublicVaultRouter](/src/interfaces/IArrakisPublicVaultRouter.sol/interface.IArrakisPublicVaultRouter.md), ReentrancyGuard, Ownable, Pausable


## State Variables
### nativeToken

```solidity
address public immutable nativeToken;
```


### permit2

```solidity
IPermit2 public immutable permit2;
```


### swapper

```solidity
IRouterSwapExecutor public immutable swapper;
```


## Functions
### onlyERC20Type


```solidity
modifier onlyERC20Type(address vault_);
```

### constructor


```solidity
constructor(address nativeToken_, address permit2_, address swapper_, address owner_);
```

### pause

function used to pause the router.

*only callable by owner*


```solidity
function pause() external whenNotPaused onlyOwner;
```

### unpause

function used to unpause the router.

*only callable by owner*


```solidity
function unpause() external whenPaused onlyOwner;
```

### addLiquidity

addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function addLiquidity(AddLiquidityData memory params_)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.vault)
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
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.addData.vault)
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
function removeLiquidity(RemoveLiquidityData memory params_)
    external
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.vault)
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


### addLiquidityPermit2

addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)


```solidity
function addLiquidityPermit2(AddLiquidityPermit2Data memory params_)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.addData.vault)
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
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.swapAndAddData.addData.vault)
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
    nonReentrant
    whenNotPaused
    onlyERC20Type(params_.removeData.vault)
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


### receive


```solidity
receive() external payable;
```

### _addLiquidity


```solidity
function _addLiquidity(
    address vault_,
    uint256 amount0_,
    uint256 amount1_,
    uint256 shares_,
    address receiver_,
    address token0_,
    address token1_
) internal;
```

### _swapAndAddLiquidity


```solidity
function _swapAndAddLiquidity(SwapAndAddData memory params_, address token0_, address token1_)
    internal
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived, uint256 amount0Diff, uint256 amount1Diff);
```

### _removeLiquidity


```solidity
function _removeLiquidity(RemoveLiquidityData memory params_) internal returns (uint256 amount0, uint256 amount1);
```

### _permit2Add


```solidity
function _permit2Add(AddLiquidityPermit2Data memory params_, uint256 amount0_, uint256 amount1_) internal;
```

### _permit2SwapAndAdd


```solidity
function _permit2SwapAndAdd(SwapAndAddPermit2Data memory params_) internal;
```

### _getMintAmounts


```solidity
function _getMintAmounts(address vault_, uint256 maxAmount0_, uint256 maxAmount1_)
    internal
    view
    returns (uint256 shareToMint, uint256 amount0ToDeposit, uint256 amount1ToDeposit);
```
