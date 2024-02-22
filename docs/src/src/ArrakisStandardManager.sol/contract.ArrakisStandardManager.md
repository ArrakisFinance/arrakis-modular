# ArrakisStandardManager
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/ArrakisStandardManager.sol)

**Inherits:**
[IArrakisStandardManager](/src/interfaces/IArrakisStandardManager.sol/interface.IArrakisStandardManager.md), [IManager](/src/interfaces/IManager.sol/interface.IManager.md), Ownable, ReentrancyGuardUpgradeable, PausableUpgradeable


## State Variables
### defaultFeePIPS

```solidity
uint256 public immutable defaultFeePIPS;
```


### nativeToken

```solidity
address public immutable nativeToken;
```


### nativeTokenDecimals

```solidity
uint8 public immutable nativeTokenDecimals;
```


### defaultReceiver

```solidity
address public defaultReceiver;
```


### receiversByToken

```solidity
mapping(address => address) public receiversByToken;
```


### vaultInfo

```solidity
mapping(address => VaultInfo) public vaultInfo;
```


### pendingFeeIncrease

```solidity
mapping(address => FeeIncrease) public pendingFeeIncrease;
```


### factory

```solidity
address public factory;
```


### _guardian

```solidity
address internal immutable _guardian;
```


### _vaults

```solidity
EnumerableSet.AddressSet internal _vaults;
```


## Functions
### onlyVaultOwner


```solidity
modifier onlyVaultOwner(address vault_);
```

### onlyWhitelistedVault


```solidity
modifier onlyWhitelistedVault(address vault_);
```

### onlyGuardian


```solidity
modifier onlyGuardian();
```

### constructor


```solidity
constructor(uint256 defaultFeePIPS_, address nativeToken_, uint8 nativeTokenDecimals_, address guardian_);
```

### initialize

function used to initialize standard manager proxy.

*we are not checking if the default fee pips is not zero, to have
the option to set 0 as default fee pips.*


```solidity
function initialize(address owner_, address defaultReceiver_, address factory_) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`owner_`|`address`|address of the owner of standard manager.|
|`defaultReceiver_`|`address`|address of the receiver of tokens (by default).|
|`factory_`|`address`|ArrakisMetaVaultFactory contract address.|


### pause

function used to pause the manager.

*only callable by guardian*


```solidity
function pause() external whenNotPaused onlyGuardian;
```

### unpause

function used to unpause the manager.

*only callable by guardian*


```solidity
function unpause() external whenPaused onlyGuardian;
```

### setDefaultReceiver

function used to set the default receiver of tokens earned.


```solidity
function setDefaultReceiver(address newDefaultReceiver_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDefaultReceiver_`|`address`|address of the new default receiver of tokens.|


### setReceiverByToken

function used to set receiver of a specific token.


```solidity
function setReceiverByToken(address vault_, bool isSetReceiverToken0_, address receiver_)
    external
    onlyOwner
    onlyWhitelistedVault(vault_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the meta vault that contain the specific token.|
|`isSetReceiverToken0_`|`bool`|boolean if true means that receiver is for token0 if not it's for token1.|
|`receiver_`|`address`|address of the receiver of this specific token.|


### decreaseManagerFeePIPS

function used to decrease the fees taken by manager for a specific vault.


```solidity
function decreaseManagerFeePIPS(address vault_, uint24 newFeePIPS_) external onlyOwner onlyWhitelistedVault(vault_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault.|
|`newFeePIPS_`|`uint24`|fees in pips to set on the specific vault.|


### finalizeIncreaseManagerFeePIPS

function used to finalize a time lock fees increase on a vault.


```solidity
function finalizeIncreaseManagerFeePIPS(address vault_) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault where the fees increase will be applied.|


### submitIncreaseManagerFeePIPS

function used to submit a fees increase in a managed vault.


```solidity
function submitIncreaseManagerFeePIPS(address vault_, uint24 newFeePIPS_)
    external
    onlyOwner
    onlyWhitelistedVault(vault_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault where fees will be increase after timeLock.|
|`newFeePIPS_`|`uint24`|fees in pips to set on the specific managed vault.|


### withdrawManagerBalance

function used by manager to get his balance of fees earned
on a vault.


```solidity
function withdrawManagerBalance(address vault_)
    external
    onlyOwner
    nonReentrant
    whenNotPaused
    returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|from which fees will be collected.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 sent to receiver_|
|`amount1`|`uint256`|amount of token1 sent to receiver_|


### rebalance

NOTE I removed this line bc if vault removal is a thing then we'd still want to colect on _previously whitelisted vaults_

function used to manage vault's strategy.


```solidity
function rebalance(address vault_, bytes[] calldata payloads_)
    external
    nonReentrant
    whenNotPaused
    onlyWhitelistedVault(vault_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault that need a rebalance.|
|`payloads_`|`bytes[]`|call data to do specific action of vault side.|


### setModule

function used to set a new module (strategy) for the vault.


```solidity
function setModule(address vault_, address module_, bytes[] calldata payloads_)
    external
    whenNotPaused
    onlyWhitelistedVault(vault_);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault the manager want to change module.|
|`module_`|`address`|address of the new module.|
|`payloads_`|`bytes[]`|call data to initialize position on the new module.|


### initManagement

function used to init management of a meta vault.


```solidity
function initManagement(SetupParams calldata params_) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SetupParams`|struct containing all the data for initialize the vault.|


### updateVaultInfo

function used to update meta vault management informations.


```solidity
function updateVaultInfo(SetupParams calldata params_)
    external
    whenNotPaused
    onlyWhitelistedVault(params_.vault)
    onlyVaultOwner(params_.vault);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SetupParams`|struct containing all the data for updating the vault.|


### initializedVaults

function used to get a list of managed vaults.


```solidity
function initializedVaults(uint256 startIndex_, uint256 endIndex_)
    external
    view
    whenNotPaused
    returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startIndex_`|`uint256`|starting index from which the caller want to read the array of managed vaults.|
|`endIndex_`|`uint256`|ending index until which the caller want to read the array of managed vaults.|


### receive


```solidity
receive() external payable;
```

### numInitializedVaults

function used to get the number of vault under management.


```solidity
function numInitializedVaults() external view returns (uint256 numberOfVaults);
```

### guardian

address of the pauser of manager.


```solidity
function guardian() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|pauser address that can pause/unpause manager.|


### isManaged

function used to know if a vault is under management by this manager.


```solidity
function isManaged(address vault_) external view returns (bool);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the meta vault the caller want to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`bool`|isManaged boolean which is true if the vault is under management, false otherwise.|


### getInitManagementSelector

function used to know the selector of initManagement functions.


```solidity
function getInitManagementSelector() external pure returns (bytes4 selector);
```

### _initManagement


```solidity
function _initManagement(SetupParams memory params_) internal;
```

### _updateParamsChecks


```solidity
function _updateParamsChecks(SetupParams memory params_) internal view;
```

