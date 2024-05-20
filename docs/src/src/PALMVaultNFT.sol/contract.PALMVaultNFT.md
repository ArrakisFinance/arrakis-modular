# PrivateVaultNFT
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/PrivateVaultNFT.sol)

**Inherits:**
Ownable, ERC721, [IPrivateVaultNFT](/src/interfaces/IPrivateVaultNFT.sol/interface.IPrivateVaultNFT.md)


## Functions
### constructor


```solidity
constructor() ERC721("Arrakis Modular Private Vaults", "RAKIS-PV-NFT");
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


