// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisPublicVaultMock {
    address public manager;

    function setManager(address manager_) external {
        manager = manager_;
    }
}
