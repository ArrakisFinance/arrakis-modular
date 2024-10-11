# NFTSVGUtils
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/utils/NFTSVGUtils.sol)


## State Variables
### HEX_DIGITS

```solidity
bytes16 private constant HEX_DIGITS = "0123456789abcdef";
```


## Functions
### generateSVGLogo

Generates the logo for the NFT.


```solidity
function generateSVGLogo() public pure returns (string memory);
```

### addressToString

Converts an address to 2 string slices.


```solidity
function addressToString(address addr_)
    public
    pure
    returns (string memory, string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`addr_`|`address`|address to convert to string.|


### uintToFloatString

Converts uints to float strings with 4 decimal places.


```solidity
function uintToFloatString(
    uint256 value_,
    uint8 decimals_
) public pure returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value_`|`uint256`|uint to convert to string.|
|`decimals_`|`uint8`|number of decimal places of the input value.|


### _uintToString

Code borrowed form:
https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol

Converts uints to strings.


```solidity
function _uintToString(uint256 value_)
    internal
    pure
    returns (string memory str);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`value_`|`uint256`|uint to convert to string.|


