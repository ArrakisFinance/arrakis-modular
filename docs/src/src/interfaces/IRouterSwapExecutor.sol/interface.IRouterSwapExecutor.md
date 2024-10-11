# IRouterSwapExecutor
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IRouterSwapExecutor.sol)


## Functions
### swap

function used to swap tokens.


```solidity
function swap(SwapAndAddData memory _swapData)
    external
    payable
    returns (uint256 amount0Diff, uint256 amount1Diff);
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

