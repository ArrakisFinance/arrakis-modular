// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisMetaVaultMock {
    address public manager;
    address public token0;
    address public token1;
    address public owner;

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setToken0AndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setOwner(address owner_) external {
        owner = owner_;
    }
}
