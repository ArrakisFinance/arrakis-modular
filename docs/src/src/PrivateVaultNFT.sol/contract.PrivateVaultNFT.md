# PrivateVaultNFT
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/PrivateVaultNFT.sol)

**Inherits:**
Ownable, ERC721, [IPrivateVaultNFT](/src/interfaces/IPrivateVaultNFT.sol/interface.IPrivateVaultNFT.md)


## State Variables
### renderController

```solidity
address public immutable renderController;
```


## Functions
### constructor


```solidity
constructor() ERC721("Arrakis Private LP NFT", "ARRAKIS");
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


### tokenURI


```solidity
function tokenURI(uint256 tokenId_)
    public
    view
    override
    returns (string memory);
```

### getMetaDatas


```solidity
function getMetaDatas(
    address token0_,
    address token1_
)
    public
    view
    returns (
        uint8 decimals0,
        uint8 decimals1,
        string memory symbol0,
        string memory symbol1
    );
```

