# IArrakisStandardManager
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisStandardManager.sol)


## Functions
### pause

function used to pause the manager.

*only callable by guardian*


```solidity
function pause() external;
```

### unpause

function used to unpause the manager.

*only callable by guardian*


```solidity
function unpause() external;
```

### setDefaultReceiver

function used to set the default receiver of tokens earned.


```solidity
function setDefaultReceiver(address newDefaultReceiver_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newDefaultReceiver_`|`address`|address of the new default receiver of tokens.|


### setReceiverByToken

function used to set receiver of a specific token.


```solidity
function setReceiverByToken(address vault_, bool isSetReceiverToken0_, address receiver_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the meta vault that contain the specific token.|
|`isSetReceiverToken0_`|`bool`|boolean if true means that receiver is for token0 if not it's for token1.|
|`receiver_`|`address`|address of the receiver of this specific token.|


### decreaseManagerFeePIPS

function used to decrease the fees taken by manager for a specific managed vault.


```solidity
function decreaseManagerFeePIPS(address vault_, uint24 newFeePIPS_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault.|
|`newFeePIPS_`|`uint24`|fees in pips to set on the specific vault.|


### finalizeIncreaseManagerFeePIPS

function used to finalize a time lock fees increase on a vault.


```solidity
function finalizeIncreaseManagerFeePIPS(address vault_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault where the fees increase will be applied.|


### submitIncreaseManagerFeePIPS

function used to submit a fees increase in a managed vault.


```solidity
function submitIncreaseManagerFeePIPS(address vault_, uint24 newFeePIPS_) external;
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
function withdrawManagerBalance(address vault_) external returns (uint256 amount0, uint256 amount1);
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

function used to manage vault's strategy.


```solidity
function rebalance(address vault_, bytes[] calldata payloads_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the vault that need a rebalance.|
|`payloads_`|`bytes[]`|call data to do specific action of vault side.|


### setModule

function used to set a new module (strategy) for the vault.


```solidity
function setModule(address vault_, address module_, bytes[] calldata payloads_) external;
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
function initManagement(SetupParams calldata params_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SetupParams`|struct containing all the data for initialize the vault.|


### updateVaultInfo

function used to update meta vault management informations.


```solidity
function updateVaultInfo(SetupParams calldata params_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`params_`|`SetupParams`|struct containing all the data for updating the vault.|


### initializedVaults

function used to get a list of managed vaults.


```solidity
function initializedVaults(uint256 startIndex_, uint256 endIndex_) external view returns (address[] memory);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`startIndex_`|`uint256`|starting index from which the caller want to read the array of managed vaults.|
|`endIndex_`|`uint256`|ending index until which the caller want to read the array of managed vaults.|


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


### factory

address of the vault factory.


```solidity
function factory() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|factory address that can deploy meta vault.|


### defaultFeePIPS

function used to get the default fee applied on manager vault.


```solidity
function defaultFeePIPS() external view returns (uint256);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`|defaultFeePIPS amount of default fees.|


### nativeToken

function used to get the native token/coin of the chain.


```solidity
function nativeToken() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|nativeToken address of the native token/coin of the chain.|


### nativeTokenDecimals

function used to get the native token/coin decimals precision.


```solidity
function nativeTokenDecimals() external view returns (uint8);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint8`|nativeTokenDecimals decimals precision of the native coin.|


### defaultReceiver

function used to get the default receiver of tokens earned in managed vault.


```solidity
function defaultReceiver() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|defaultReceiver address of the default receiver.|


## Events
### LogWhitelistNftRebalancers

```solidity
event LogWhitelistNftRebalancers(address[] nftRebalancers);
```

### LogBlacklistNftRebalancers

```solidity
event LogBlacklistNftRebalancers(address[] nftRebalancers);
```

### LogWhitelistStrategies

```solidity
event LogWhitelistStrategies(string[] strategies);
```

### LogSetManagementParams

```solidity
event LogSetManagementParams(
    address indexed vault,
    address oracle,
    uint24 maxSlippagePIPS,
    uint24 maxDeviation,
    uint256 cooldownPeriod,
    address executor,
    address stratAnnouncer
);
```

### LogSetVaultData

```solidity
event LogSetVaultData(address indexed vault, bytes datas);
```

### LogSetVaultStrat

```solidity
event LogSetVaultStrat(address indexed vault, string strat);
```

### LogFundBalance

```solidity
event LogFundBalance(address indexed vault, uint256 balance);
```

### LogWithdrawVaultBalance

```solidity
event LogWithdrawVaultBalance(address indexed vault, uint256 amount, address receiver, uint256 newBalance);
```

### LogSetDefaultReceiver

```solidity
event LogSetDefaultReceiver(address oldReceiver, address newReceiver);
```

### LogSetReceiverByToken

```solidity
event LogSetReceiverByToken(address indexed token, address receiver);
```

### LogWithdrawManagerBalance

```solidity
event LogWithdrawManagerBalance(address indexed receiver0, address indexed receiver1, uint256 amount0, uint256 amount1);
```

### LogChangeManagerFee

```solidity
event LogChangeManagerFee(address vault, uint256 newFeePIPS);
```

### LogIncreaseManagerFeeSubmission

```solidity
event LogIncreaseManagerFeeSubmission(address vault, uint256 newFeePIPS);
```

### LogRebalance

```solidity
event LogRebalance(address indexed vault, bytes[] payloads);
```

### LogSetModule

```solidity
event LogSetModule(address indexed vault, address module, bytes[] payloads);
```

### LogSetFactory

```solidity
event LogSetFactory(address vaultFactory);
```

## Errors
### EmptyNftRebalancersArray

```solidity
error EmptyNftRebalancersArray();
```

### NotWhitelistedNftRebalancer

```solidity
error NotWhitelistedNftRebalancer(address nftRebalancer);
```

### AlreadyWhitelistedNftRebalancer

```solidity
error AlreadyWhitelistedNftRebalancer(address nftRebalancer);
```

### OnlyNftRebalancers

```solidity
error OnlyNftRebalancers(address caller);
```

### EmptyString

```solidity
error EmptyString();
```

### StratAlreadyWhitelisted

```solidity
error StratAlreadyWhitelisted();
```

### StratNotWhitelisted

```solidity
error StratNotWhitelisted();
```

### OnlyPrivateVault

```solidity
error OnlyPrivateVault();
```

### OnlyERC20Vault

```solidity
error OnlyERC20Vault();
```

### OnlyVaultOwner

```solidity
error OnlyVaultOwner(address caller, address vaultOwner);
```

### AlreadyInManagement

```solidity
error AlreadyInManagement();
```

### NotTheManager

```solidity
error NotTheManager(address caller, address manager);
```

### SlippageTooHigh

```solidity
error SlippageTooHigh();
```

### MaxDeviationTooHigh

```solidity
error MaxDeviationTooHigh();
```

### CooldownPeriodSetToZero

```solidity
error CooldownPeriodSetToZero();
```

### ValueDtBalanceInputed

```solidity
error ValueDtBalanceInputed(uint256 value, uint256 balance);
```

### OnlyOwner

```solidity
error OnlyOwner();
```

### OnlyManagedVault

```solidity
error OnlyManagedVault();
```

### DataIsUpdated

```solidity
error DataIsUpdated();
```

### SameStrat

```solidity
error SameStrat();
```

### NotWhitelistedStrat

```solidity
error NotWhitelistedStrat();
```

### NotNativeCoinSent

```solidity
error NotNativeCoinSent();
```

### NoEnoughBalance

```solidity
error NoEnoughBalance();
```

### OverMaxSlippage

```solidity
error OverMaxSlippage();
```

### NativeTokenDecimalsZero

```solidity
error NativeTokenDecimalsZero();
```

### NotFeeDecrease

```solidity
error NotFeeDecrease();
```

### AlreadyPendingIncrease

```solidity
error AlreadyPendingIncrease();
```

### NotFeeIncrease

```solidity
error NotFeeIncrease();
```

### TimeNotPassed

```solidity
error TimeNotPassed();
```

### NoPendingIncrease

```solidity
error NoPendingIncrease();
```

### NotExecutor

```solidity
error NotExecutor();
```

### NotStratAnnouncer

```solidity
error NotStratAnnouncer();
```

### AddressZero

```solidity
error AddressZero();
```

### NotWhitelistedVault

```solidity
error NotWhitelistedVault(address vault);
```

### AlreadyWhitelistedVault

```solidity
error AlreadyWhitelistedVault(address vault);
```

### EmptyVaultsArray

```solidity
error EmptyVaultsArray();
```

### CallFailed

```solidity
error CallFailed(bytes payload);
```

### StartIndexLtEndIndex

```solidity
error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);
```

### EndIndexGtNbOfVaults

```solidity
error EndIndexGtNbOfVaults(uint256 endIndex, uint256 numberOfVaults);
```

### OnlyGuardian

```solidity
error OnlyGuardian(address caller, address guardian);
```

### FactoryAlreadySet

```solidity
error FactoryAlreadySet();
```

### OnlyFactory

```solidity
error OnlyFactory(address caller, address factory);
```

### VaultNotDeployed

```solidity
error VaultNotDeployed();
```

