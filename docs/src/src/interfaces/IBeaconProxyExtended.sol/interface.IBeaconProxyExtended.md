# IBeaconProxyExtended
[Git Source](https://github.com/ArrakisFinance/arrakis-modular/blob/main/src/interfaces/IBeaconProxyExtended.sol)


## Functions
### beacon

function used to get the addess of the upgradeabilitybeacon associated
to the beaconProxy.


```solidity
function beacon() external view returns (address upgradeableBeacon);
```
**Returns**

|Name|Type|Description|
|----|----|-----------|
|`upgradeableBeacon`|`address`|address of the UpgradeableBeacon that contain the implementation.|


