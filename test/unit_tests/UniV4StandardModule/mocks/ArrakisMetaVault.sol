// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisMetaVaultMock {
    address public manager;

    constructor(address manager_) {
        manager = manager_;
    }

    // #region mock functions.

    function setManager(address manager_) external {
        manager = manager_;
    }

    // #endregion mock functions.
}
