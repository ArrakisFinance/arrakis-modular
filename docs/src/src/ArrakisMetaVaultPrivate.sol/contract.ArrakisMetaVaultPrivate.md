# ArrakisMetaVaultPrivate
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/ArrakisMetaVaultPrivate.sol)

**Inherits:**
[ArrakisMetaVault](/src/abstracts/ArrakisMetaVault.sol/abstract.ArrakisMetaVault.md), [IArrakisMetaVaultPrivate](/src/interfaces/IArrakisMetaVaultPrivate.sol/interface.IArrakisMetaVaultPrivate.md), [IOwnable](/src/interfaces/IOwnable.sol/interface.IOwnable.md)


## State Variables
### nft

```solidity
address public immutable nft;
```


### _depositors

```solidity
EnumerableSet.AddressSet internal _depositors;
```


## Functions
### constructor


```solidity
constructor(address moduleRegistry_, address manager_, address nft_) ArrakisMetaVault(moduleRegistry_, manager_);
```

### deposit

function used to deposit tokens or expand position inside the
inherent strategy.


```solidity
function deposit(uint256 amount0_, uint256 amount1_) external payable;
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


### whitelistDepositors

function used to whitelist depositors.


```solidity
function whitelistDepositors(address[] calldata depositors_) external onlyOwnerCustom;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositors_`|`address[]`| list of address that will be granted to depositor role.|


### blacklistDepositors

function used to blacklist depositors.


```solidity
function blacklistDepositors(address[] calldata depositors_) external onlyOwnerCustom;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`depositors_`|`address[]`|list of address who depositor role will be revoked.|


### owner

function used to get the owner of this contract.


```solidity
function owner() external view returns (address);
```

### depositors

function used to get the list of depositors.


```solidity
function depositors() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|depositors list of address granted to depositor role.|


### _deposit


```solidity
function _deposit(uint256 amount0_, uint256 amount1_) internal nonReentrant;
```

### _onlyOwnerCheck

*msg.sender should be the tokens provider*


```solidity
function _onlyOwnerCheck() internal view override;
```

