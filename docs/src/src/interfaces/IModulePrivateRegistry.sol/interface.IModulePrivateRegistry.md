# IModulePrivateRegistry
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IModulePrivateRegistry.sol)


## Events
### LogCreatePrivateModule
Log creation of a private module.


```solidity
event LogCreatePrivateModule(
    address beacon,
    bytes payload,
    address vault,
    address creator,
    address module
);
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
### NotPrivateVault

```solidity
error NotPrivateVault();
```

