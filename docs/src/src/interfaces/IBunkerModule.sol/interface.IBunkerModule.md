# IBunkerModule
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/4485c572ded3a830c181fa38ceaac13efe8eb7f1/src/interfaces/IBunkerModule.sol)


## Functions
### initialize

initialize function to delegate call onced the beacon proxy is deployed,
for initializing the bunker module.


```solidity
function initialize(address metaVault_) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`metaVault_`|`address`|address of the meta vault|


## Errors
### NotImplemented

```solidity
error NotImplemented();
```

### AmountsZeros

```solidity
error AmountsZeros();
```

