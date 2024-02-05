# SOTOracleWrapper
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/modules/SOTOracleWrapper.sol)

**Inherits:**
[IOracleWrapper](/src/interfaces/IOracleWrapper.sol/interface.IOracleWrapper.md)


## State Variables
### oracle

```solidity
ISOTOracle public immutable oracle;
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
constructor(address oracle_);
```

### getPrice0


```solidity
function getPrice0() public view returns (uint256 price0);
```

### getPrice1


```solidity
function getPrice1() public view returns (uint256 price1);
```
