# ComputeFeesPayload
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/structs/SUniswapV4.sol)


```solidity
struct ComputeFeesPayload {
    uint256 feeGrowthInsideLast;
    uint256 feeGrowthOutsideLower;
    uint256 feeGrowthOutsideUpper;
    uint256 feeGrowthGlobal;
    IPoolManager poolManager;
    PoolKey poolKey;
    uint128 liquidity;
    int24 tick;
    int24 lowerTick;
    int24 upperTick;
}
```
