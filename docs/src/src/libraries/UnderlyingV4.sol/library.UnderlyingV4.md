# UnderlyingV4
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/libraries/UnderlyingV4.sol)


## Functions
### totalUnderlyingForMint


```solidity
function totalUnderlyingForMint(
    UnderlyingPayload memory underlyingPayload_,
    uint256 proportion_
) public view returns (uint256 amount0, uint256 amount1);
```

### totalUnderlyingWithFees


```solidity
function totalUnderlyingWithFees(
    UnderlyingPayload memory underlyingPayload_
)
    public
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );
```

### totalUnderlyingAtPriceWithFees


```solidity
function totalUnderlyingAtPriceWithFees(
    UnderlyingPayload memory underlyingPayload_,
    uint160 sqrtPriceX96_
)
    public
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );
```

### underlying


```solidity
function underlying(
    RangeData memory underlying_,
    uint160 sqrtPriceX96_
)
    public
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );
```

### underlyingMint


```solidity
function underlyingMint(
    RangeData memory underlying_,
    uint256 proportion_
)
    public
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );
```

### getUnderlyingBalancesMint


```solidity
function getUnderlyingBalancesMint(
    PositionUnderlying memory positionUnderlying_,
    uint256 proportion_
)
    public
    view
    returns (
        uint256 amount0Current,
        uint256 amount1Current,
        uint256 fee0,
        uint256 fee1
    );
```

### getUnderlyingBalances


```solidity
function getUnderlyingBalances(
    PositionUnderlying memory positionUnderlying_
)
    public
    view
    returns (
        uint256 amount0Current,
        uint256 amount1Current,
        uint256 fee0,
        uint256 fee1
    );
```

### getAmountsForDelta

Computes the token0 and token1 value for a given amount of liquidity, the current
pool prices and the prices at the tick boundaries


```solidity
function getAmountsForDelta(
    uint160 sqrtRatioX96,
    uint160 sqrtRatioAX96,
    uint160 sqrtRatioBX96,
    int128 liquidity
) public pure returns (uint256 amount0, uint256 amount1);
```

### _getFeesOwned


```solidity
function _getFeesOwned(
    Position.State memory self,
    uint256 feeGrowthInside0X128,
    uint256 feeGrowthInside1X128
) internal view returns (uint256 feesOwed0, uint256 feesOwed1);
```

### _totalUnderlyingWithFees


```solidity
function _totalUnderlyingWithFees(
    UnderlyingPayload memory underlyingPayload_,
    uint160 sqrtPriceX96_
)
    private
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 fee0,
        uint256 fee1
    );
```

