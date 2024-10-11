# IUniV4StandardModuleResolver
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IUniV4StandardModuleResolver.sol)


## Functions
### poolManager


```solidity
function poolManager() external returns (address);
```

### computeMintAmounts


```solidity
function computeMintAmounts(
    uint256 current0_,
    uint256 current1_,
    uint256 totalSupply_,
    uint256 amount0Max_,
    uint256 amount1Max_
) external pure returns (uint256 mintAmount);
```

## Errors
### MaxAmountsTooLow

```solidity
error MaxAmountsTooLow();
```

### AddressZero

```solidity
error AddressZero();
```

### MintZero

```solidity
error MintZero();
```

### NotSupported

```solidity
error NotSupported();
```

