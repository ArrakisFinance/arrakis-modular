# RouterSwapExecutor
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/RouterSwapExecutor.sol)

**Inherits:**
[IRouterSwapExecutor](/src/interfaces/IRouterSwapExecutor.sol/interface.IRouterSwapExecutor.md)


## State Variables
### router

```solidity
address public immutable router;
```


### nativeToken

```solidity
address public immutable nativeToken;
```


## Functions
### onlyRouter


```solidity
modifier onlyRouter();
```

### constructor


```solidity
constructor(address router_, address nativeToken_);
```

### swap

function used to swap tokens.


```solidity
function swap(SwapAndAddData memory params_)
    external
    payable
    onlyRouter
    returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SwapAndAddData`|struct containing all the informations for swapping.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|the difference in token0 amount before and after the swap.|
|`amount1Diff`|`uint256`|the difference in token1 amount before and after the swap.|


