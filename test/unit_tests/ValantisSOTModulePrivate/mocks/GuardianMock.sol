// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract GuardianMock {
    address public pauser;

    function setPauser(address pauser_) external {
        pauser = pauser_;
    }
}
