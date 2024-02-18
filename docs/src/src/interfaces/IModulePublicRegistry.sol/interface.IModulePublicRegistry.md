# IModulePublicRegistry
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/9091a6ee814f061039fd7b968feddb93bbdf1110/src/interfaces/IModulePublicRegistry.sol)


## Events
### LogCreatePublicModule
Log creation of a public module.


```solidity
event LogCreatePublicModule(address beacon, bytes payload, address vault, address creator, address module);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`beacon`|`address`|which beacon from who we get the implementation.|
|`payload`|`bytes`|payload sent to the module constructor.|
|`vault`|`address`|address of the Arrakis Meta Vault that will own this module|
|`creator`|`address`|address that create the module.|
|`module`|`address`|address of the newly created module.|

## Errors
### NotPublicVault

```solidity
error NotPublicVault();
```

