// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract BeaconImplementation {
    address public metaVault;
    address public guardian;

    function setGuardianAndMetaVault(
        address guardian_,
        address metaVault_
    ) external {
        guardian = guardian_;
        metaVault = metaVault_;
    }
}
