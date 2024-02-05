# VaultInfo
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/structs/SManager.sol)


```solidity
struct VaultInfo {
    uint256 lastRebalance;
    uint256 cooldownPeriod;
    IOracleWrapper oracle;
    uint24 maxDeviation;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
    uint24 managerFeePIPS;
}
```

