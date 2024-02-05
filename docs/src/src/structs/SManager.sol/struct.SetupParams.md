# SetupParams
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/structs/SManager.sol)


```solidity
struct SetupParams {
    address vault;
    IOracleWrapper oracle;
    uint24 maxDeviation;
    uint256 cooldownPeriod;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
}
```

