# IOracleWrapper
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IOracleWrapper.sol)


## Functions
### getPrice0

function used to get price0.


```solidity
function getPrice0() external view returns (uint256 price0);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price0`|`uint256`|price of token0/token1.|


### getPrice1

function used to get price1.


```solidity
function getPrice1() external view returns (uint256 price1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`price1`|`uint256`|price of token1/token0.|


## Errors
### AddressZero

```solidity
error AddressZero();
```

### DecimalsToken0Zero

```solidity
error DecimalsToken0Zero();
```

### DecimalsToken1Zero

```solidity
error DecimalsToken1Zero();
```

