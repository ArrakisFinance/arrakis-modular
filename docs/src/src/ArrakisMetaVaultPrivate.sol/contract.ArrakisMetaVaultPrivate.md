# ArrakisMetaVaultPrivate
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/ArrakisMetaVaultPrivate.sol)

**Inherits:**
[ArrakisMetaVault](/src/abstracts/ArrakisMetaVault.sol/abstract.ArrakisMetaVault.md), [IArrakisMetaVaultPrivate](/src/interfaces/IArrakisMetaVaultPrivate.sol/interface.IArrakisMetaVaultPrivate.md)


## State Variables
### nft

```solidity
address public immutable nft;
```


## Functions
### constructor


```solidity
constructor(address token0_, address token1_, address moduleRegistry_, address manager_, address nft_)
    ArrakisMetaVault(token0_, token1_, moduleRegistry_, manager_);
```

### deposit

function used to deposit tokens or expand position inside the
inherent strategy.


```solidity
function deposit(uint256 amount0_, uint256 amount1_) external payable onlyOwnerCustom;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount0_`|`uint256`|amount of token0 need to increase the position by proportion_;|
|`amount1_`|`uint256`|amount of token1 need to increase the position by proportion_;|


### withdraw

function used to withdraw tokens or position contraction of the
underpin strategy.


```solidity
function withdraw(uint256 proportion_, address receiver_)
    external
    onlyOwnerCustom
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`proportion_`|`uint256`|the proportion of position contraction.|
|`receiver_`|`address`|the address that will receive withdrawn tokens.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 returned.|
|`amount1`|`uint256`|amount of token1 returned.|


### vaultType

function used to get the type of vault.


```solidity
function vaultType() external pure returns (bytes32);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bytes32`|vaultType as bytes32.|


### _deposit


```solidity
function _deposit(uint256 amount0_, uint256 amount1_) internal nonReentrant;
```

### _onlyOwnerCheck

*msg.sender should be the tokens provider*


```solidity
function _onlyOwnerCheck() internal view override;
```

