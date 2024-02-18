# SetupParams
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/9091a6ee814f061039fd7b968feddb93bbdf1110/src/structs/SManager.sol)


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

