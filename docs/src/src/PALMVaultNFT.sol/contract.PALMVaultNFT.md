# PALMVaultNFT
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/PALMVaultNFT.sol)

**Inherits:**
Ownable, ERC721, [IPALMVaultNFT](/src/interfaces/IPALMVaultNFT.sol/interface.IPALMVaultNFT.md)


## Functions
### constructor


```solidity
constructor() ERC721("Arrakis Modular PALM Vaults", "PALM");
```

### mint

function used to mint nft (representing a vault) and send it.


```solidity
function mint(address to_, uint256 tokenId_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to_`|`address`|address where to send the NFT.|
|`tokenId_`|`uint256`|id of the NFT to mint.|


