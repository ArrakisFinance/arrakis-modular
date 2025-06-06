# IModuleRegistry
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IModuleRegistry.sol)

**Author:**
Arrakis Team.

interface of module registry that contains all whitelisted modules.


## Functions
### beacons

function to get the whitelisted list of IBeacon
that have module as implementation.


```solidity
function beacons() external view returns (address[] memory beacons);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`beacons`|`address[]`|list of upgradeable beacon.|


### beaconsContains

function to know if the beacons enumerableSet contain
beacon_


```solidity
function beaconsContains(address beacon_)
    external
    view
    returns (bool isContained);
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


### admin

function used to get the admin address that can
upgrade beacon implementation.

*admin address should be a timelock contract.*


```solidity
function admin() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|admin address that can upgrade beacon implementation.|


### initialize

*function used to initialize module registry.*


```solidity
function initialize(address factory_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`factory_`|`address`|address of ArrakisMetaVaultFactory, who is the only one who can call the init management function.|


### whitelistBeacons

function used to whitelist IBeacon  that contain
implementation of valid module.


```solidity
function whitelistBeacons(address[] calldata beacons_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|list of beacon to whitelist.|


### blacklistBeacons

function used to blacklist IBeacon that contain
implementation of unvalid (from now) module.


```solidity
function blacklistBeacons(address[] calldata beacons_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|list of beacon to blacklist.|


### createModule

function used to create module instance that can be
whitelisted as module inside a vault.


```solidity
function createModule(
    address vault_,
    address beacon_,
    bytes calldata payload_
) external returns (address module);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`||
|`beacon_`|`address`|which whitelisted beacon's implementation we want to create an instance of.|
|`payload_`|`bytes`|payload to create the module.|


## Events
### LogWhitelistBeacons
Log whitelist action of beacons.


```solidity
event LogWhitelistBeacons(address[] beacons);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons`|`address[]`|list of beacons whitelisted.|

### LogBlacklistBeacons
Log blacklist action of beacons.


```solidity
event LogBlacklistBeacons(address[] beacons);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons`|`address[]`|list of beacons blacklisted.|

## Errors
### AddressZero

```solidity
error AddressZero();
```

### AlreadyWhitelistedBeacon

```solidity
error AlreadyWhitelistedBeacon(address beacon);
```

### NotAlreadyWhitelistedBeacon

```solidity
error NotAlreadyWhitelistedBeacon(address beacon);
```

### NotWhitelistedBeacon

```solidity
error NotWhitelistedBeacon();
```

### NotBeacon

```solidity
error NotBeacon();
```

### ModuleNotLinkedToMetaVault

```solidity
error ModuleNotLinkedToMetaVault();
```

### NotSameGuardian

```solidity
error NotSameGuardian();
```

### NotSameAdmin

```solidity
error NotSameAdmin();
```

