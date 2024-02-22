# VaultInfo
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/9091a6ee814f061039fd7b968feddb93bbdf1110/src/structs/SManager.sol)


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

