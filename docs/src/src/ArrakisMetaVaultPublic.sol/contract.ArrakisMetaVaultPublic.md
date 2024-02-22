# ArrakisMetaVaultPublic
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/ArrakisMetaVaultPublic.sol)

**Inherits:**
[IArrakisMetaVaultPublic](/src/interfaces/IArrakisMetaVaultPublic.sol/interface.IArrakisMetaVaultPublic.md), [ArrakisMetaVault](/src/abstracts/ArrakisMetaVault.sol/abstract.ArrakisMetaVault.md), Ownable, ERC20


## State Variables
### _name

```solidity
string internal _name;
```


### _symbol

```solidity
string internal _symbol;
```


## Functions
### constructor


```solidity
constructor(address owner_, string memory name_, string memory symbol_, address moduleRegistry_, address manager_)
    ArrakisMetaVault(moduleRegistry_, manager_);
```

### mint

function used to mint share of the vault position


```solidity
function mint(uint256 shares_, address receiver_) external payable returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares_`|`uint256`|amount representing the part of the position owned by receiver.|
|`receiver_`|`address`|address where share token will be sent.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 deposited.|
|`amount1`|`uint256`|amount of token1 deposited.|


### burn

function used to burn share of the vault position.


```solidity
function burn(uint256 shares_, address receiver_) external returns (uint256 amount0, uint256 amount1);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares_`|`uint256`|amount of share that will be burn.|
|`receiver_`|`address`|address where underlying tokens will be sent.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`amount0`|`uint256`|amount of token0 withdrawn.|
|`amount1`|`uint256`|amount of token1 withdrawn.|


### transferOwnership

*override transfer of ownership, to make it not possible.*


```solidity
function transferOwnership(address) public payable override;
```

### renounceOwnership

*override transfer of ownership, to make it not possible.*


```solidity
function renounceOwnership() public payable override;
```

### completeOwnershipHandover

*override transfer of ownership, to make it not possible.*


```solidity
function completeOwnershipHandover(address) public payable override;
```

### name

function used to get the name of the LP token.


```solidity
function name() public view override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|name string value containing the name.|


### symbol

function used to get the symbol of the LP token.


```solidity
function symbol() public view override returns (string memory);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`string`|symbol string value containing the symbol.|


### _deposit


```solidity
function _deposit(uint256 proportion_) internal nonReentrant returns (uint256 amount0, uint256 amount1);
```

### _onlyOwnerCheck

*msg.sender should be the tokens provider*


```solidity
function _onlyOwnerCheck() internal view override;
```

