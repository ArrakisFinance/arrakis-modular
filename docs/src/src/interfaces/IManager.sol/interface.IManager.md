# IManager
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/interfaces/IManager.sol)


## Functions
### getInitManagementSelector

function used to know the selector of initManagement functions.


```solidity
function getInitManagementSelector() external pure returns (bytes4 selector);
```

### isManaged

function used to know if a vault is under management by this manager.


```solidity
function isManaged(address vault_) external view returns (bool isManaged);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`|address of the meta vault the caller want to check.|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`isManaged`|`bool`|boolean which is true if the vault is under management, false otherwise.|


