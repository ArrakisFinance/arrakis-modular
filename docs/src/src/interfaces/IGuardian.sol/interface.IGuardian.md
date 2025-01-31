# IGuardian
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IGuardian.sol)


## Functions
### pauser

function to get the address of the pauser of arrakis
protocol.


```solidity
function pauser() external view returns (address);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`address`|pauser address that can pause the arrakis protocol.|


### setPauser

function to set the pauser of Arrakis protocol.


```solidity
function setPauser(address newPauser_) external;
```

## Events
### LogSetPauser
event emitted when the pauser is set by the owner of the Guardian.


```solidity
event LogSetPauser(address oldPauser, address newPauser);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`oldPauser`|`address`|address of the previous pauser.|
|`newPauser`|`address`|address of the current pauser.|

## Errors
### AddressZero

```solidity
error AddressZero();
```

### SamePauser

```solidity
error SamePauser();
```

