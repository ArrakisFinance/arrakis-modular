# IArrakisMetaVaultFactory
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisMetaVaultFactory.sol)


## Functions
### pause

function used to pause the factory.

*only callable by owner.*


```solidity
function pause() external;
```

### unpause

function used to unpause the factory.

*only callable by owner.*


```solidity
function unpause() external;
```

### setManager

function used to set a new manager.

*only callable by owner.*


```solidity
function setManager(address newManager_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newManager_`|`address`|address that will managed newly created vault.|


### deployPublicVault

function used to deploy ERC20 token wrapped Arrakis
Meta Vault.


```solidity
function deployPublicVault(
    bytes32 salt_,
    address token0_,
    address token1_,
    address owner_,
    address beacon_,
    bytes calldata moduleCreationPayload_,
    bytes calldata initManagementPayload_
) external returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt_`|`bytes32`|bytes32 used to get a deterministic all chains address.|
|`token0_`|`address`|address of the first token of the token pair.|
|`token1_`|`address`|address of the second token of the token pair.|
|`owner_`|`address`|address of the owner of the vault.|
|`beacon_`|`address`|address of the beacon that will be used to create the default module.|
|`moduleCreationPayload_`|`bytes`|payload for initializing the module.|
|`initManagementPayload_`|`bytes`|data for initialize management.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|address of the newly created Token Meta Vault.|


### deployPrivateVault

function used to deploy owned Arrakis
Meta Vault.


```solidity
function deployPrivateVault(
    bytes32 salt_,
    address token0_,
    address token1_,
    address owner_,
    address beacon_,
    bytes calldata moduleCreationPayload_,
    bytes calldata initManagementPayload_
) external returns (address vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`salt_`|`bytes32`|bytes32 needed to compute vault address deterministic way.|
|`token0_`|`address`|address of the first token of the token pair.|
|`token1_`|`address`|address of the second token of the token pair.|
|`owner_`|`address`|address of the owner of the vault.|
|`beacon_`|`address`|address of the beacon that will be used to create the default module.|
|`moduleCreationPayload_`|`bytes`|payload for initializing the module.|
|`initManagementPayload_`|`bytes`|data for initialize management.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`vault`|`address`|address of the newly created private Meta Vault.|


### whitelistDeployer

function used to grant the role to deploy to a list of addresses.


```solidity
function whitelistDeployer(address[] calldata deployers_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers_`|`address[]`|list of addresses that owner want to grant permission to deploy.|


### blacklistDeployer

function used to grant the role to deploy to a list of addresses.


```solidity
function blacklistDeployer(address[] calldata deployers_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers_`|`address[]`|list of addresses that owner want to grant permission to deploy.|


### getTokenName

get Arrakis Modular standard token name for two corresponding tokens.


```solidity
function getTokenName(address token0_, address token1_) external view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token0_`|`address`|address of the first token.|
|`token1_`|`address`|address of the second token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|name name of the arrakis modular token vault.|


### getTokenSymbol

get Arrakis Modular standard token symbol for two corresponding tokens.


```solidity
function getTokenSymbol(address token0_, address token1_) external view returns (string memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`token0_`|`address`|address of the first token.|
|`token1_`|`address`|address of the second token.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|symbol symbol of the arrakis modular token vault.|


### publicVaults

get a list of public vaults created by this factory


```solidity
function publicVaults(uint256 startIndex_, uint256 endIndex_) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startIndex_`|`uint256`|start index|
|`endIndex_`|`uint256`|end index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|vaults list of all created vaults.|


### numOfPublicVaults

numOfPublicVaults counts the total number of token vaults in existence


```solidity
function numOfPublicVaults() external view returns (uint256 result);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`uint256`|total number of vaults deployed|


### isPublicVault

isPublicVault check if the inputed vault is a public vault.


```solidity
function isPublicVault(address vault_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isPublicVault true if the inputed vault is public or otherwise false.|


### privateVaults

get a list of private vaults created by this factory


```solidity
function privateVaults(uint256 startIndex_, uint256 endIndex_) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startIndex_`|`uint256`|start index|
|`endIndex_`|`uint256`|end index|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address[]`|vaults list of all created vaults.|


### numOfPrivateVaults

numOfPrivateVaults counts the total number of private vaults in existence


```solidity
function numOfPrivateVaults() external view returns (uint256 result);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`result`|`uint256`|total number of vaults deployed|


### isPrivateVault

isPrivateVault check if the inputed vault is a private vault.


```solidity
function isPrivateVault(address vault_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the address to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isPublicVault true if the inputed vault is private or otherwise false.|


### manager

function used to get the manager of newly deployed vault.


```solidity
function manager() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|manager address that will manager vault that will be created.|


### deployers

function used to get a list of address that can deploy public vault.


```solidity
function deployers() external view returns (address[] memory);
```

### moduleRegistryPublic

function used to get public module registry.


```solidity
function moduleRegistryPublic() external view returns (address);
```

### moduleRegistryPrivate

function used to get private module registry.


```solidity
function moduleRegistryPrivate() external view returns (address);
```

## Events
### LogPublicVaultCreation
event emitted when public vault is created by a deployer.


```solidity
event LogPublicVaultCreation(
    address indexed creator,
    bytes32 salt,
    address token0,
    address token1,
    address owner,
    address module,
    address publicVault,
    address timeLock
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creator`|`address`|address that is creating the public vault, a deployer.|
|`salt`|`bytes32`|salt used for create3.|
|`token0`|`address`|first token of the token pair.|
|`token1`|`address`|second token of the token pair.|
|`owner`|`address`|address of the owner.|
|`module`|`address`|default module that will be used by the meta vault.|
|`publicVault`|`address`|address of the deployed meta vault.|
|`timeLock`|`address`|timeLock that will owned the meta vault.|

### LogPrivateVaultCreation
event emitted when private vault is created.


```solidity
event LogPrivateVaultCreation(
    address indexed creator,
    bytes32 salt,
    address token0,
    address token1,
    address owner,
    address module,
    address privateVault
);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creator`|`address`|address that is deploying the vault.|
|`salt`|`bytes32`|salt used for create3.|
|`token0`|`address`|address of the first token of the pair.|
|`token1`|`address`|address of the second token of the pair.|
|`owner`|`address`|address that will owned the private vault.|
|`module`|`address`|address of the default module.|
|`privateVault`|`address`|address of the deployed meta vault.|

### LogWhitelistDeployers
event emitted when whitelisting an array of public vault
deployers.


```solidity
event LogWhitelistDeployers(address[] deployers);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers`|`address[]`|list of deployers added to the whitelist.|

### LogBlacklistDeployers
event emitted when blacklisting an array of public vault
deployers.


```solidity
event LogBlacklistDeployers(address[] deployers);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers`|`address[]`|list of deployers removed from the whitelist.|

### LogSetManager
event emitted when owner set a new manager.


```solidity
event LogSetManager(address oldManager, address newManager);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldManager`|`address`|address of the previous manager.|
|`newManager`|`address`|address of the new manager.|

## Errors
### AddressZero

```solidity
error AddressZero();
```

### StartIndexLtEndIndex
*triggered when querying vaults on factory
and start index is lower than end index.*


```solidity
error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);
```

### EndIndexGtNbOfVaults
*triggered when querying vaults on factory
and end index of the query is bigger the biggest index of the vaults array.*


```solidity
error EndIndexGtNbOfVaults(uint256 endIndex, uint256 numberOfVaults);
```

### AlreadyWhitelistedDeployer
*triggered when owner want to whitelist a deployer that has been already
whitelisted.*


```solidity
error AlreadyWhitelistedDeployer(address deployer);
```

### NotAlreadyADeployer
*triggered when owner want to blackist a deployer that is not a current
deployer.*


```solidity
error NotAlreadyADeployer(address deployer);
```

### NotADeployer
*triggered when public vault deploy function is
called by an address that is not a deployer.*


```solidity
error NotADeployer();
```

### CallFailed
*triggered when init management low level failed.*


```solidity
error CallFailed();
```

### VaultNotManaged
*triggered when init management happened and still the vault is
not under management by manager.*


```solidity
error VaultNotManaged();
```

### SameManager
*triggered when owner is setting a new manager, and the new manager
address match with the old manager address.*


```solidity
error SameManager();
```

