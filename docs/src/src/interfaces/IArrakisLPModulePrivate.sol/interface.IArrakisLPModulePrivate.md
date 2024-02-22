# IArrakisLPModulePrivate
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisLPModulePrivate.sol)

expose a deposit function for that can
deposit any share of token0 and token1.

*this deposit feature will be used by
private actor.*


## Functions
### fund

deposit function for private vault.


```solidity
function fund(address depositor_, uint256 amount0_, uint256 amount1_) external payable;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor_`|`address`|address that will provide the tokens.|
|`amount0_`|`uint256`|amount of token0 that depositor want to send to module.|
|`amount1_`|`uint256`|amount of token1 that depositor want to send to module.|


## Events
### LogFund
event emitted when owner of private fund the private vault.


```solidity
event LogFund(address depositor, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositor`|`address`|address that are sending the tokens, the owner.|
|`amount0`|`uint256`|amount of token0 sent by depositor.|
|`amount1`|`uint256`|amount of token1 sent by depositor.|

## Errors
### DepositZero

```solidity
error DepositZero();
```

