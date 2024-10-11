# RouterSwapResolver
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/RouterSwapResolver.sol)

**Inherits:**
[IRouterSwapResolver](/src/interfaces/IRouterSwapResolver.sol/interface.IRouterSwapResolver.md)


## State Variables
### router

```solidity
IArrakisPublicVaultRouter public immutable router;
```


## Functions
### constructor


```solidity
constructor(address router_);
```

### calculateSwapAmount


```solidity
function calculateSwapAmount(
    IArrakisMetaVault vault_,
    uint256 amount0In_,
    uint256 amount1In_,
    uint256 price18Decimals_
) external view returns (bool zeroForOne, uint256 swapAmount);
```

### _getUnderlyingOrLiquidity


```solidity
function _getUnderlyingOrLiquidity(IArrakisMetaVault vault_)
    internal
    view
    returns (uint256 gross0, uint256 gross1);
```

