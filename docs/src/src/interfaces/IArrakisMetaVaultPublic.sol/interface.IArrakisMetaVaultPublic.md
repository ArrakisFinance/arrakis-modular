# IArrakisMetaVaultPublic
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/22c7b5c5fce6ff4d3a051aa4fbf376745815e340/src/interfaces/IArrakisMetaVaultPublic.sol)


## Functions
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


## Events
### LogMint
event emitted when a user mint some shares on a public vault.


```solidity
event LogMint(uint256 shares, address receiver, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|amount of shares minted.|
|`receiver`|`address`|address that will receive the LP token (shares).|
|`amount0`|`uint256`|amount of token0 needed to mint shares.|
|`amount1`|`uint256`|amount of token1 needed to mint shares.|

### LogBurn
event emitted when a user burn some of his shares.


```solidity
event LogBurn(uint256 shares, address receiver, uint256 amount0, uint256 amount1);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`shares`|`uint256`|amount of share burned by the user.|
|`receiver`|`address`|address that will receive amounts of tokens related to burning the shares.|
|`amount0`|`uint256`|amount of token0 that is collected from burning shares.|
|`amount1`|`uint256`|amount of token1 that is collected from burning shares.|

## Errors
### MintZero

```solidity
error MintZero();
```

### BurnZero

```solidity
error BurnZero();
```

### BurnOverflow

```solidity
error BurnOverflow();
```

### CannotMintProportionZero

```solidity
error CannotMintProportionZero();
```

### CannotBurnProportionZero

```solidity
error CannotBurnProportionZero();
```

