# NFTSVG
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/utils/NFTSVG.sol)

**Inherits:**
[INFTSVG](/src/utils/NFTSVG.sol/interface.INFTSVG.md)


## Functions
### isNFTSVG

Checks if the contract is compliant with the NFTSVG interface


```solidity
function isNFTSVG() external pure returns (bool);
```

### generateVaultURI

Generates a URI for a given vault


```solidity
function generateVaultURI(SVGParams memory params_)
    public
    pure
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SVGParams`|Parameters for generating the URI|


### generateFallbackURI

Generates a fallback URI for a given vault


```solidity
function generateFallbackURI(SVGParams memory params_)
    public
    pure
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SVGParams`|Parameters for generating the URI|


### _generateName

Generates the name of the URI for a given vault


```solidity
function _generateName(SVGParams memory params_)
    internal
    pure
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SVGParams`|Parameters for generating the URI|


### _generateDescription

Generates the description of the URI for a given vault


```solidity
function _generateDescription(SVGParams memory params_)
    internal
    pure
    returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SVGParams`|Parameters for generating the URI|


### _generateSVGImage

Generates the SVG image of the URI for a given vault


```solidity
function _generateSVGImage(address vault_)
    internal
    pure
    returns (string memory svg);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|The vault address represented by the NFT|


### _generateSVGDefs


```solidity
function _generateSVGDefs() internal pure returns (string memory);
```

### _generateSVGMasks


```solidity
function _generateSVGMasks() internal pure returns (string memory);
```

### _generateSVGFrame


```solidity
function _generateSVGFrame() internal pure returns (string memory);
```

### _generateSVGDunes


```solidity
function _generateSVGDunes() internal pure returns (string memory);
```

### _generateSVGFront


```solidity
function _generateSVGFront() internal pure returns (string memory);
```

### _generateSVGBack


```solidity
function _generateSVGBack(address vault_)
    internal
    pure
    returns (string memory);
```

