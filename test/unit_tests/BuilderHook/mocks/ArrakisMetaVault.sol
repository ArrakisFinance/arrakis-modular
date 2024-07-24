// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisMetaVaultMock {
    address public manager;
    address public owner;

    constructor(address manager_, address owner_) {
        manager = manager_;
        owner = owner_;
    }

    // #region mock functions.

    function setManager(address manager_) external {
        manager = manager_;
    }

    // #endregion mock functions.
}
