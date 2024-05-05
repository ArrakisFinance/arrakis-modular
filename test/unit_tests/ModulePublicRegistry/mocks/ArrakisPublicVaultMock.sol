// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract ArrakisPublicVaultMock {
    address public manager;

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setModule(address module) external {}

    function withdrawManagerFee()
        external
        returns (uint256 amount0, uint256 amount1)
    {}
}
