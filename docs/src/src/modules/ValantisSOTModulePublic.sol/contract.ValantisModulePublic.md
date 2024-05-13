# ValantisModulePublic
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/modules/ValantisHOTModulePublic.sol)

**Inherits:**
[ValantisModule](/src/abstracts/ValantisHOTModule.sol/abstract.ValantisModule.md), [IArrakisLPModulePublic](/src/interfaces/IArrakisLPModulePublic.sol/interface.IArrakisLPModulePublic.md)


## Functions
### deposit

deposit function for public vault.


```solidity
function deposit(address depositor_, uint256 proportion_)
    external
    payable
    onlyMetaVault
    whenNotPaused
    nonReentrant
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor_`|`address`|address that will provide the tokens.|
|`proportion_`|`uint256`|percentage of portfolio position vault want to expand.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 needed to expand the portfolio by "proportion" percent.|
|`amount1`|`uint256`|amount of token1 needed to expand the portfolio by "proportion" percent.|


