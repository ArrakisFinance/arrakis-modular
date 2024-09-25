// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisMetaVaultMock {
    address public manager;
    address public owner;
    address public token0;
    address public token1;

    constructor(address manager_, address owner_) {
        manager = manager_;
        owner = owner_;
    }

    // #region mock functions.

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setTokens(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    // #endregion mock functions.
}