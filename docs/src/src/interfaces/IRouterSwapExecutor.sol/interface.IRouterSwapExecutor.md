# IRouterSwapExecutor
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IRouterSwapExecutor.sol)


## Functions
### swap

function used to swap tokens.


```solidity
function swap(SwapAndAddData memory _swapData) external payable returns (uint256 amount0Diff, uint256 amount1Diff);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`_swapData`|`SwapAndAddData`|struct containing all the informations for swapping.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0Diff`|`uint256`|the difference in token0 amount before and after the swap.|
|`amount1Diff`|`uint256`|the difference in token1 amount before and after the swap.|


## Errors
### OnlyRouter

```solidity
error OnlyRouter(address caller, address router);
```

### AddressZero

```solidity
error AddressZero();
```

### SwapCallFailed

```solidity
error SwapCallFailed();
```

### ReceivedBelowMinimum

```solidity
error ReceivedBelowMinimum();
```

