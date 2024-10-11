# ValantisModulePrivate
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/modules/ValantisHOTModulePrivate.sol)

**Inherits:**
[ValantisModule](/src/abstracts/ValantisHOTModule.sol/abstract.ValantisModule.md), [IArrakisLPModulePrivate](/src/interfaces/IArrakisLPModulePrivate.sol/interface.IArrakisLPModulePrivate.md)


## Functions
### constructor


```solidity
constructor(address guardian_) ValantisModule(guardian_);
```

### fund

deposit function for private vault.


```solidity
function fund(
    address depositor_,
    uint256 amount0_,
    uint256 amount1_
) external payable onlyMetaVault whenNotPaused nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor_`|`address`|address that will provide the tokens.|
|`amount0_`|`uint256`|amount of token0 that depositor want to send to module.|
|`amount1_`|`uint256`|amount of token1 that depositor want to send to module.|


