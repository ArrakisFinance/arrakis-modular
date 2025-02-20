# ModulePrivateRegistry
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/ModulePrivateRegistry.sol)

**Inherits:**
[ModuleRegistry](/src/abstracts/ModuleRegistry.sol/abstract.ModuleRegistry.md), [IModulePrivateRegistry](/src/interfaces/IModulePrivateRegistry.sol/interface.IModulePrivateRegistry.md)


## Functions
### constructor


```solidity
constructor(
    address owner_,
    address guardian_,
    address admin_
) ModuleRegistry(owner_, guardian_, admin_);
```

### createModule

function used to create module instance that can be
whitelisted as module inside a vault.


```solidity
function createModule(
    address vault_,
    address beacon_,
    bytes calldata payload_
) external returns (address module);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`vault_`|`address`||
|`beacon_`|`address`|which whitelisted beacon's implementation we want to create an instance of.|
|`payload_`|`bytes`|payload to create the module.|


