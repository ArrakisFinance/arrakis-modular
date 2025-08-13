// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

contract GuardianMock {
    address public pauser;

    constructor(
        address pauser_
    ) {
        pauser = pauser_;
    }
}
