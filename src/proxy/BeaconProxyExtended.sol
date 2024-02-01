// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";

contract BeaconProxyExtended is BeaconProxy {
    constructor(
        address beacon_,
        bytes memory data_
    ) payable BeaconProxy(beacon_, data_) {}

    function beacon() external view returns(address) {
        return _getBeacon();
    }
}
