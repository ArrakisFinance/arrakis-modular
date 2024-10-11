# ArrakisPrivateVaultRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/ArrakisPrivateVaultRouter.sol)

**Inherits:**
[IArrakisPrivateVaultRouter](/src/interfaces/IArrakisPrivateVaultRouter.sol/interface.IArrakisPrivateVaultRouter.md), ReentrancyGuard, Ownable, Pausable


## State Variables
### nativeToken
address of the native token.


```solidity
address public immutable nativeToken;
```


### permit2
permit2 contract address.


```solidity
IPermit2 public immutable permit2;
```


### factory
arrakis meta vault factory contract address.


```solidity
IArrakisMetaVaultFactory public immutable factory;
```


### weth
wrapped eth contract address.


```solidity
IWETH9 public immutable weth;
```


### swapper
swap executor contract address.


```solidity
IPrivateRouterSwapExecutor public swapper;
```


## Functions
### onlyPrivateVault


```solidity
modifier onlyPrivateVault(address vault_);
```

### onlyDepositor


```solidity
modifier onlyDepositor(address vault_);
```

### constructor


```solidity
constructor(
    address nativeToken_,
    address permit2_,
    address owner_,
    address factory_,
    address weth_
);
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

### updateSwapExecutor


```solidity
function updateSwapExecutor(address swapper_)
    external
    whenNotPaused
    onlyOwner;
```

### addLiquidity

addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)


```solidity
function addLiquidity(AddLiquidityData memory params_)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.vault)
    onlyDepositor(params_.vault);
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
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.addData.vault)
    onlyDepositor(params_.addData.vault)
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
    payable
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.addData.vault)
    onlyDepositor(params_.addData.vault);
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
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.swapAndAddData.addData.vault)
    onlyDepositor(params_.swapAndAddData.addData.vault)
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
    payable
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.vault)
    onlyDepositor(params_.vault);
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
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.addData.vault)
    onlyDepositor(params_.addData.vault)
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
)
    external
    payable
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.addData.vault)
    onlyDepositor(params_.addData.vault);
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
    nonReentrant
    whenNotPaused
    onlyPrivateVault(params_.swapAndAddData.addData.vault)
    onlyDepositor(params_.swapAndAddData.addData.vault)
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
    address token0_,
    address token1_
) internal;
```

### _swapAndAddLiquidity


```solidity
function _swapAndAddLiquidity(
    SwapAndAddData memory params_,
    address token0_,
    address token1_
) internal returns (uint256 amount0Diff, uint256 amount1Diff);
```

### _swapAndAddLiquiditySendBackLeftOver


```solidity
function _swapAndAddLiquiditySendBackLeftOver(
    SwapAndAddData memory params_,
    address token0_,
    address token1_
) internal returns (uint256 amount0Diff, uint256 amount1Diff);
```

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

### _permit2AddLengthOneOrTwo


```solidity
function _permit2AddLengthOneOrTwo(
    AddLiquidityPermit2Data memory params_,
    address token0_,
    address token1_,
    uint256 amount0_,
    uint256 amount1_
) internal;
```

### _permit2Add


```solidity
function _permit2Add(
    uint256 permittedLength_,
    AddLiquidityPermit2Data memory params_,
    address token0_,
    address token1_,
    uint256 amount0_,
    uint256 amount1_
) internal;
```

### _permit2SwapAndAddLengthOne


```solidity
function _permit2SwapAndAddLengthOne(
    SwapAndAddPermit2Data memory params_,
    address token0_,
    address token1_
) internal;
```

### _permit2SwapAndAddLengthOneOrTwo


```solidity
function _permit2SwapAndAddLengthOneOrTwo(
    SwapAndAddPermit2Data memory params_,
    address token0_,
    address token1_
) internal;
```

### _permit2SwapAndAdd


```solidity
function _permit2SwapAndAdd(
    uint256 permittedLength_,
    SwapAndAddPermit2Data memory params_,
    address token0_,
    address token1_
) internal;
```

