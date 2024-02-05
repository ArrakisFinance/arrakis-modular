// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBeaconProxyExtended {
    /// @notice function used to get the addess of the upgradeabilitybeacon associated
    /// to the beaconProxy.
    /// @return upgradeableBeacon address of the UpgradeableBeacon that contain the
    /// implementation.
    function beacon() external view returns(address upgradeableBeacon);
}