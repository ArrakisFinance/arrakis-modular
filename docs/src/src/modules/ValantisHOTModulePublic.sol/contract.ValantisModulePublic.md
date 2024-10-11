# ValantisModulePublic
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/modules/ValantisHOTModulePublic.sol)

**Inherits:**
[ValantisModule](/src/abstracts/ValantisHOTModule.sol/abstract.ValantisModule.md), [IArrakisLPModulePublic](/src/interfaces/IArrakisLPModulePublic.sol/interface.IArrakisLPModulePublic.md)


## State Variables
### notFirstDeposit

```solidity
bool public notFirstDeposit;
```


## Functions
### constructor


```solidity
constructor(address guardian_) ValantisModule(guardian_);
```

### deposit

deposit function for public vault.


```solidity
function deposit(
    address depositor_,
    uint256 proportion_
)
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


### withdraw

function used by metaVault to withdraw tokens from the strategy.


```solidity
function withdraw(
    address receiver_,
    uint256 proportion_
) public override returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`receiver_`|`address`|address that will receive tokens.|
|`proportion_`|`uint256`|number of share needed to be withdrawn.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 withdrawn.|
|`amount1`|`uint256`|amount of token1 withdrawn.|


### initializePosition


```solidity
function initializePosition(bytes calldata data_)
    external
    override
    onlyMetaVault;
```

