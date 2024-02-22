# ModuleRegistry
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/abstracts/ModuleRegistry.sol)

**Inherits:**
[IModuleRegistry](/src/interfaces/IModuleRegistry.sol/interface.IModuleRegistry.md), Ownable


## State Variables
### factory

```solidity
IArrakisMetaVaultFactory public immutable factory;
```


### admin
*should be a timelock contract.*


```solidity
address public admin;
```


### _guardian

```solidity
address internal immutable _guardian;
```


### _beacons

```solidity
EnumerableSet.AddressSet internal _beacons;
```


## Functions
### constructor


```solidity
constructor(address factory_, address owner_, address guardian_, address admin_);
```

### beacons

function to get the whitelisted list of IBeacon
that have module as implementation.


```solidity
function beacons() external view returns (address[] memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|beacons list of upgradeable beacon.|


### beaconsContains

function to know if the beacons enumerableSet contain
beacon_


```solidity
function beaconsContains(address beacon_) external view returns (bool isContained);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacon_`|`address`|beacon address to check|


### guardian

function used to get the guardian address of arrakis protocol.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|guardian address of the pauser.|


### whitelistBeacons

function used to whitelist IBeacon  that contain
implementation of valid module.


```solidity
function whitelistBeacons(address[] calldata beacons_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|list of beacon to whitelist.|


### blacklistBeacons

function used to blacklist IBeacon that contain
implementation of unvalid (from now) module.


```solidity
function blacklistBeacons(address[] calldata beacons_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|list of beacon to blacklist.|


### _createModule


```solidity
function _createModule(address vault_, address beacon_, bytes calldata payload_) internal returns (address module);
```

### _checkVaultNotAddressZero


```solidity
function _checkVaultNotAddressZero(address vault_) internal;
```

