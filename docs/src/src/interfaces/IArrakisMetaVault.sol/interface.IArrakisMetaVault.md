# IArrakisMetaVault
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisMetaVault.sol)

IArrakisMetaVault is a vault that is able to invest dynamically deposited
tokens into protocols through his module.


## Functions
### initialize

function used to initialize default module.


```solidity
function initialize(address token0_, address token1_, address module_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token0_`|`address`|address of the first token of the token pair.|
|`token1_`|`address`|address of the second token of the token pair.|
|`module_`|`address`|address of the default module.|


### setModule

function used to set module


```solidity
function setModule(address module_, bytes[] calldata payloads_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module_`|`address`|address of the new module|
|`payloads_`|`bytes[]`|datas to initialize/rebalance on the new module|


### whitelistModules

function used to whitelist modules that can used by manager.


```solidity
function whitelistModules(address[] calldata beacons_, bytes[] calldata data_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|array of beacons addresses to use for modules creation.|
|`data_`|`bytes[]`|array of payload to use for modules creation.|


### blacklistModules

function used to blacklist modules that can used by manager.


```solidity
function blacklistModules(address[] calldata modules_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`modules_`|`address[]`|array of module addresses to be blacklisted.|


### whitelistedModules

function used to get the list of modules whitelisted.


```solidity
function whitelistedModules() external view returns (address[] memory modules);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`modules`|`address[]`|whitelisted modules addresses.|


### totalUnderlying

function used to get the amount of token0 and token1 sitting
on the position.


```solidity
function totalUnderlying() external view returns (uint256 amount0, uint256 amount1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position.|
|`amount1`|`uint256`|the amount of token1 sitting on the position.|


### totalUnderlyingAtPrice

function used to get the amounts of token0 and token1 sitting
on the position for a specific price.


```solidity
function totalUnderlyingAtPrice(uint160 priceX96) external view returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceX96`|`uint160`|price at which we want to simulate our tokens composition|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position for priceX96.|
|`amount1`|`uint256`|the amount of token1 sitting on the position for priceX96.|


### getInits

function used to get the initial amounts needed to open a position.


```solidity
function getInits() external view returns (uint256 init0, uint256 init1);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`init0`|`uint256`|the amount of token0 needed to open a position.|
|`init1`|`uint256`|the amount of token1 needed to open a position.|


### token0

function used to get the address of token0.


```solidity
function token0() external view returns (address);
```

### token1

function used to get the address of token1.


```solidity
function token1() external view returns (address);
```

### manager

function used to get manager address.


```solidity
function manager() external view returns (address);
```

### module

function used to get module used to
open/close/manager a position.


```solidity
function module() external view returns (IArrakisLPModule);
```

### moduleRegistry

function used to get module registry.


```solidity
function moduleRegistry() external view returns (address registry);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`registry`|`address`|address of module registry.|


## Events
### LogWithdrawManagerBalance
Event describing a manager fee withdrawal.


```solidity
event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 that manager has earned and will be transfered.|
|`amount1`|`uint256`|amount of token1 that manager has earned and will be transfered.|

### LogSetManager
Event describing owner setting the manager.


```solidity
event LogSetManager(address manager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`manager`|`address`|address of manager that will manage the portfolio.|

### LogSetModule
Event describing manager setting the module.


```solidity
event LogSetModule(address module, bytes[] payloads);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`address`|address of the new active module.|
|`payloads`|`bytes[]`|data payloads for initializing positions on the new module.|

### LogSetFirstModule
Event describing default module that the vault will be initialized with.


```solidity
event LogSetFirstModule(address module);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`address`|address of the default module.|

### LogWhiteListedModules
Event describing list of modules that has been whitelisted by owner.


```solidity
event LogWhiteListedModules(address[] modules);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`modules`|`address[]`|list of addresses corresponding to new modules now available to be activated by manager.|

### LogWhitelistedModule
Event describing whitelisted of the first module during vault creation.


```solidity
event LogWhitelistedModule(address module);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module`|`address`|default activation.|

### LogBlackListedModules
Event describing blacklisting action of modules by owner.


```solidity
event LogBlackListedModules(address[] modules);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`modules`|`address[]`|list of addresses corresponding to old modules that has been blacklisted.|

## Errors
### AddressZero
*triggered when an address that should not
be zero is equal to address zero.*


```solidity
error AddressZero(string property);
```

### OnlyManager
*triggered when the caller is different than
the manager.*


```solidity
error OnlyManager(address caller, address manager);
```

### CallFailed
*triggered when a low level call failed during
execution.*


```solidity
error CallFailed();
```

### SameModule
*triggered when manager try to set the active
module as active.*


```solidity
error SameModule();
```

### SameManager
*triggered when owner of the vault try to set the
manager with the current manager.*


```solidity
error SameManager();
```

### ModuleNotEmpty
*triggered when all tokens withdrawal has been done
during a switch of module.*


```solidity
error ModuleNotEmpty(uint256 amount0, uint256 amount1);
```

### AlreadyWhitelisted
*triggered when owner try to whitelist a module
that has been already whitelisted.*


```solidity
error AlreadyWhitelisted(address module);
```

### NotWhitelistedModule
*triggered when owner try to blacklist a module
that has not been whitelisted.*


```solidity
error NotWhitelistedModule(address module);
```

### ActiveModule
*triggered when owner try to blacklist the active module.*


```solidity
error ActiveModule();
```

### Token0GtToken1
*triggered during vault creation if token0 address is greater than
token1 address.*


```solidity
error Token0GtToken1();
```

### Token0EqToken1
*triggered during vault creation if token0 address is equal to
token1 address.*


```solidity
error Token0EqToken1();
```

### NotWhitelistedBeacon
*triggered when whitelisting action is occuring and module's beacon
is not whitelisted on module registry.*


```solidity
error NotWhitelistedBeacon();
```

### NotSameGuardian
*triggered when guardian of the whitelisting module is different than
the guardian of the registry.*


```solidity
error NotSameGuardian();
```

### NotImplemented
*triggered when a function logic is not implemented.*


```solidity
error NotImplemented();
```

### ArrayNotSameLength
*triggered when two arrays suppposed to have the same length, have different length.*


```solidity
error ArrayNotSameLength();
```

### OnlyOwner
*triggered when function is called by someone else than the owner.*


```solidity
error OnlyOwner();
```

