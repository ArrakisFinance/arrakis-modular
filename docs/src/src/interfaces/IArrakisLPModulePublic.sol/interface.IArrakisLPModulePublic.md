# IArrakisLPModulePublic
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisLPModulePublic.sol)

expose a deposit function for that can
deposit a specific share of token0 and token1.

*this deposit feature will be used by public actor.*


## Functions
### deposit

deposit function for public vault.


```solidity
function deposit(address depositor_, uint256 proportion_) external payable returns (uint256 amount0, uint256 amount1);
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


## Events
### LogDeposit
Event describing a deposit done by an user inside this module.

*deposit action can be indexed by depositor.*


```solidity
event LogDeposit(address depositor, uint256 proportion, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor`|`address`|address of the tokens provider.|
|`proportion`|`uint256`|percentage of the current position that depositor want to increase.|
|`amount0`|`uint256`|amount of token0 needed to increase the portfolio of "proportion" percent.|
|`amount1`|`uint256`|amount of token1 needed to increase the portfolio of "proportion" percent.|

