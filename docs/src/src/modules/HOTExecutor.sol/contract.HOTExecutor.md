# HOTExecutor
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/modules/HOTExecutor.sol)

**Inherits:**
[IHOTExecutor](/src/interfaces/IHOTExecutor.sol/interface.IHOTExecutor.md), Ownable


## State Variables
### manager

```solidity
address public immutable manager;
```


### w3f

```solidity
address public w3f;
```


## Functions
### constructor


```solidity
constructor(address manager_, address w3f_, address owner_);
```

### setW3f


```solidity
function setW3f(address newW3f_) external onlyOwner;
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

