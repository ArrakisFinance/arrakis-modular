# Withdraw
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/structs/SUniswapV4.sol)


```solidity
struct Withdraw {
    IPoolManager poolManager;
    address receiver;
    uint256 proportion;
    uint256 amount0;
    uint256 amount1;
    uint256 fee0;
    uint256 fee1;
}
```

