// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PRIVATE_TYPE} from "../../../../src/constants/CArrakis.sol";

contract ArrakisPrivateVaultMock {
    address public manager;

    function vaultType() external pure returns (bytes32) {
        return PRIVATE_TYPE;
    }

    function setManager(address manager_) external {
        manager = manager_;
    }
}