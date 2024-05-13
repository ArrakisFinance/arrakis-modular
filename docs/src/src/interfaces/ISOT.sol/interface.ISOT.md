# IHOT
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IHOT.sol)


## Functions
### depositLiquidity


```solidity
function depositLiquidity(
    uint256 _amount0,
    uint256 _amount1,
    uint160 _expectedSqrtSpotPriceUpperX96,
    uint160 _expectedSqrtSpotPriceLowerX96
) external;
```

### withdrawLiquidity


```solidity
function withdrawLiquidity(
    uint256 _amount0,
    uint256 _amount1,
    address _receiver,
    uint160 _expectedSqrtSpotPriceUpperX96,
    uint160 _expectedSqrtSpotPriceLowerX96
) external;
```

### setPriceBounds


```solidity
function setPriceBounds(
    uint128 _sqrtPriceLowX96,
    uint128 _sqrtPriceHighX96,
    uint160 _expectedSqrtSpotPriceUpperX96,
    uint160 _expectedSqrtSpotPriceLowerX96
) external;
```

### getReservesAtPrice


```solidity
function getReservesAtPrice(uint160 sqrtPriceX96_) external view returns (uint128 reserves0, uint128 reserves1);
```

### getAmmState


```solidity
function getAmmState()
    external
    view
    returns (uint160 sqrtSpotPriceX96, uint160 sqrtPriceLowX96, uint160 sqrtPriceHighX96);
```

