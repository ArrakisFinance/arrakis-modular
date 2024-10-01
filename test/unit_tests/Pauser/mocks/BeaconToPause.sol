// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IPausable} from "../../../../src/interfaces/IPausable.sol";

contract BeaconToPause is IPausable {
    bool public paused;

    function pause() external override {
        paused = true;
    }

    function unpause() external override {
        paused = false;
    }
}