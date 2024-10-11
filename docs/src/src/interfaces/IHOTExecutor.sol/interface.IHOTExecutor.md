# IHOTExecutor
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IHOTExecutor.sol)


## Functions
### setW3f


```solidity
function setW3f(address newW3f_) external;
```

### rebalance


```solidity
function rebalance(
    address vault_,
    bytes[] calldata payloads_,
    uint256 expectedReservesAmount_,
    bool zeroToOne_
) external;
```

### manager


```solidity
function manager() external view returns (address);
```

### w3f


```solidity
function w3f() external view returns (address);
```

## Events
### LogSetW3f

```solidity
event LogSetW3f(address newW3f);
```

## Errors
### AddressZero

```solidity
error AddressZero();
```

### SameW3f

```solidity
error SameW3f();
```

### UnexpectedReservesAmount0

```solidity
error UnexpectedReservesAmount0();
```

### UnexpectedReservesAmount1

```solidity
error UnexpectedReservesAmount1();
```

### OnlyW3F

```solidity
error OnlyW3F();
```

