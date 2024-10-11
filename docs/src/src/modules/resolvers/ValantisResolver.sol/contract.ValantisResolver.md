# ValantisResolver
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/modules/resolvers/ValantisResolver.sol)

**Inherits:**
[IResolver](/src/interfaces/IResolver.sol/interface.IResolver.md)


## Functions
### getMintAmounts

getMintAmounts used to get the shares we can mint from some max amounts.


```solidity
function getMintAmounts(
    address vault_,
    uint256 maxAmount0_,
    uint256 maxAmount1_
)
    external
    view
    returns (
        uint256 shareToMint,
        uint256 amount0ToDeposit,
        uint256 amount1ToDeposit
    );
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|meta vault address.|
|`maxAmount0_`|`uint256`|maximum amount of token0 user want to contribute.|
|`maxAmount1_`|`uint256`|maximum amount of token1 user want to contribute.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`shareToMint`|`uint256`|maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.|
|`amount0ToDeposit`|`uint256`|amount of token0 user should deposit into the vault for minting 'shareToMint'.|
|`amount1ToDeposit`|`uint256`|amount of token1 user should deposit into the vault for minting 'shareToMint'.|


