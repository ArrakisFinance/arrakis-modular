# HOTOracleWrapper
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/modules/HOTOracleWrapper.sol)

**Inherits:**
[IOracleWrapper](/src/interfaces/IOracleWrapper.sol/interface.IOracleWrapper.md)


## State Variables
### oracle

```solidity
IHOTOracle public immutable oracle;
```


### decimals0

```solidity
uint8 public immutable decimals0;
```


### decimals1

```solidity
uint8 public immutable decimals1;
```


## Functions
### constructor


```solidity
constructor(address oracle_, uint8 decimals0_, uint8 decimals1_);
```

### getPrice0


```solidity
function getPrice0() public view returns (uint256 price0);
```

### getPrice1


```solidity
function getPrice1() public view returns (uint256 price1);
```

