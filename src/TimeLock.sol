// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ITimeLock} from "./interfaces/ITimeLock.sol";

import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

contract TimeLock is TimelockController, ITimeLock {
    constructor(
        uint256 minDelay,
        address[] memory proposers,
        address[] memory executors,
        address admin
    ) TimelockController(minDelay, proposers, executors, admin) {}

    function updateDelay(uint256) external pure override {
        revert NotImplemented();
    }
}
