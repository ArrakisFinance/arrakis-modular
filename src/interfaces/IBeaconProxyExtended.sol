// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IBeaconProxyExtended {
    function beacon() external view returns(address);
}