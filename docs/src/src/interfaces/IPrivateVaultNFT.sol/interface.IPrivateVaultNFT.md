# IPrivateVaultNFT
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IPrivateVaultNFT.sol)


## Functions
### mint

function used to mint nft (representing a vault) and send it.


```solidity
function mint(address to_, uint256 tokenId_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`to_`|`address`|address where to send the NFT.|
|`tokenId_`|`uint256`|id of the NFT to mint.|


### getMetaDatas

*for doing meta data calls of tokens.*


```solidity
function getMetaDatas(
    address token0_,
    address token1_
)
    external
    view
    returns (
        uint8 decimals0,
        uint8 decimals1,
        string memory symbol0,
        string memory symbol1
    );
```

