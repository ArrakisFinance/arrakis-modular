# IArrakisPublicVaultWethRouter
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/interfaces/IArrakisPublicVaultWethRouter.sol)


## Functions
### wrapAndAddLiquidity


```solidity
function wrapAndAddLiquidity(AddLiquidityData memory params_)
    external
    payable
    returns (uint256 amount0, uint256 amount1, uint256 sharesReceived);
```

## Errors
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

