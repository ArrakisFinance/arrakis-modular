# ArrakisMetaVault
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/abstracts/ArrakisMetaVault.sol)

**Inherits:**
[IArrakisMetaVault](/src/interfaces/IArrakisMetaVault.sol/interface.IArrakisMetaVault.md), ReentrancyGuard, Initializable


## State Variables
### moduleRegistry

```solidity
address public immutable moduleRegistry;
```


### token0

```solidity
address public token0;
```


### token1

```solidity
address public token1;
```


### module

```solidity
IArrakisLPModule public module;
```


### manager

```solidity
address public manager;
```


### _whitelistedModules

```solidity
EnumerableSet.AddressSet internal _whitelistedModules;
```


## Functions
### onlyOwnerCustom


```solidity
modifier onlyOwnerCustom();
```

### onlyManager


```solidity
modifier onlyManager();
```

### constructor


```solidity
constructor(address moduleRegistry_, address manager_);
```

### initialize


```solidity
function initialize(address token0_, address token1_, address module_) external initializer;
```

### setModule

function used to set module


```solidity
function setModule(address module_, bytes[] calldata payloads_) external onlyManager nonReentrant;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`module_`|`address`|address of the new module|
|`payloads_`|`bytes[]`|datas to initialize/rebalance on the new module|


### whitelistModules

function used to whitelist modules that can used by manager.

*we transfer here all tokens to the new module.*

*module implementation should take into account
that wrongly implemented module can freeze the modularity
of ArrakisMetaVault if withdrawManagerBalance + withdraw 100%
don't transfer every tokens (0/1) from module.*


```solidity
function whitelistModules(address[] calldata beacons_, bytes[] calldata data_) external onlyOwnerCustom;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacons_`|`address[]`|array of beacons addresses to use for modules creation.|
|`data_`|`bytes[]`|array of payload to use for modules creation.|


### blacklistModules

function used to blacklist modules that can used by manager.


```solidity
function blacklistModules(address[] calldata modules_) external onlyOwnerCustom;
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


### totalUnderlying

function used to get the amount of token0 and token1 sitting
on the position.


```solidity
function totalUnderlying() public view returns (uint256 amount0, uint256 amount1);
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
function totalUnderlyingAtPrice(uint160 priceX96_) external view returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`priceX96_`|`uint160`|price at which we want to simulate our tokens composition|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|the amount of token0 sitting on the position for priceX96.|
|`amount1`|`uint256`|the amount of token1 sitting on the position for priceX96.|


### _withdraw


```solidity
function _withdraw(address receiver_, uint256 proportion_) internal returns (uint256 amount0, uint256 amount1);
```

### _withdrawManagerBalance


```solidity
function _withdrawManagerBalance(IArrakisLPModule module_) internal returns (uint256 amount0, uint256 amount1);
```

### _onlyOwnerCheck


```solidity
function _onlyOwnerCheck() internal view virtual;
```

