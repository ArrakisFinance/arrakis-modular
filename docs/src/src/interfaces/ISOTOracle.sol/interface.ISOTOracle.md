# IHOTOracle
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IHOTOracle.sol)


## Functions
### token0Decimals


```solidity
function token0Decimals() external view returns (uint8);
```

### token1Decimals


```solidity
function token1Decimals() external view returns (uint8);
```

### token0Base


```solidity
function token0Base() external view returns (uint256);
```

### token1Base


```solidity
function token1Base() external view returns (uint256);
```

### maxOracleUpdateDuration


```solidity
function maxOracleUpdateDuration() external view returns (uint32);
```

### feedToken0


```solidity
function feedToken0() external view returns (AggregatorV3Interface);
```

### feedToken1


```solidity
function feedToken1() external view returns (AggregatorV3Interface);
```

### getSqrtOraclePriceX96


```solidity
function getSqrtOraclePriceX96() external view returns (uint160 sqrtOraclePriceX96);
```

