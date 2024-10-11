# PositionUnderlying
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/structs/SUniswapV4.sol)


```solidity
struct PositionUnderlying {
    uint160 sqrtPriceX96;
    IPoolManager poolManager;
    PoolKey poolKey;
    address self;
    int24 lowerTick;
    int24 upperTick;
}
```

