# VaultInfo
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/structs/SManager.sol)


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

