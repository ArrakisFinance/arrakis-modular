# IArrakisPrivateHook
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IArrakisPrivateHook.sol)


## Functions
### setFee


```solidity
function setFee(PoolKey calldata poolKey_, uint24 fee_) external;
```

### module


```solidity
function module() external view returns (address);
```

### vault


```solidity
function vault() external view returns (address);
```

### manager


```solidity
function manager() external view returns (address);
```

### fee


```solidity
function fee() external view returns (uint24);
```

### poolManager


```solidity
function poolManager() external view returns (address);
```

## Events
### SetFee

```solidity
event SetFee(uint24 fee);
```

## Errors
### AddressZero

```solidity
error AddressZero();
```

### OnlyModule

```solidity
error OnlyModule();
```

### NotImplemented

```solidity
error NotImplemented();
```

### OnlyVaultExecutor

```solidity
error OnlyVaultExecutor();
```

