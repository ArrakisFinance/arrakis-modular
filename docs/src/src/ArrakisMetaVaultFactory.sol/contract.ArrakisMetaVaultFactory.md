# ArrakisMetaVaultFactory
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/ArrakisMetaVaultFactory.sol)

**Inherits:**
[IArrakisMetaVaultFactory](/src/interfaces/IArrakisMetaVaultFactory.sol/interface.IArrakisMetaVaultFactory.md), Pausable, Ownable

*this contract will use create3 to deploy vaults.*


## State Variables
### moduleRegistryPublic

```solidity
address public immutable moduleRegistryPublic;
```


### moduleRegistryPrivate

```solidity
address public immutable moduleRegistryPrivate;
```


### nft

```solidity
PALMVaultNFT public immutable nft;
```


### manager

```solidity
address public manager;
```


### _publicVaults

```solidity
EnumerableSet.AddressSet internal _publicVaults;
```


### _privateVaults

```solidity
EnumerableSet.AddressSet internal _privateVaults;
```


### _deployers

```solidity
EnumerableSet.AddressSet internal _deployers;
```


## Functions
### constructor


```solidity
constructor(address owner_, address manager_, address moduleRegistryPublic_, address moduleRegistryPrivate_);
```

### pause

function used to pause the factory.

*only callable by owner.*


```solidity
function pause() external whenNotPaused onlyOwner;
```

### unpause

function used to unpause the factory.

*only callable by owner.*


```solidity
function unpause() external whenPaused onlyOwner;
```

### setManager

function used to set a new manager.

*only callable by owner.*


```solidity
function setManager(address newManager_) external onlyOwner;
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
) external whenNotPaused returns (address vault);
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
) external whenNotPaused returns (address vault);
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
function whitelistDeployer(address[] calldata deployers_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers_`|`address[]`|list of addresses that owner want to grant permission to deploy.|


### blacklistDeployer

function used to grant the role to deploy to a list of addresses.


```solidity
function blacklistDeployer(address[] calldata deployers_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`deployers_`|`address[]`|list of addresses that owner want to grant permission to deploy.|


### getTokenName

get Arrakis Modular standard token name for two corresponding tokens.


```solidity
function getTokenName(address token0_, address token1_) public view returns (string memory);
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
function getTokenSymbol(address token0_, address token1_) public view returns (string memory);
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

numOfPublicVaults counts the total number of public vaults in existence


```solidity
function numOfPublicVaults() public view returns (uint256 result);
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
function numOfPrivateVaults() public view returns (uint256 result);
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


### deployers

function used to get a list of address that can deploy public vault.


```solidity
function deployers() external view returns (address[] memory);
```

### _initManagement


```solidity
function _initManagement(address vault_, bytes memory data_) internal;
```

### _append

*to anticipate futur changes in the manager's initManagement function
manager should implement getInitManagementSelector function, so factory can get the
the right selector of the function.*

*for initializing management we need to know the vault address,
so manager should follow this pattern where vault address is the first parameter of the function.*


```solidity
function _append(string memory a_, string memory b_, string memory c_, string memory d_)
    internal
    pure
    returns (string memory);
```

