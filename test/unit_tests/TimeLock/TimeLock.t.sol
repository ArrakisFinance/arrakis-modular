// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {TimeLock} from "../../../src/TimeLock.sol";
import {ITimeLock} from "../../../src/interfaces/ITimeLock.sol";

contract TimeLockTest is TestWrapper {
    TimeLock public timeLock;

    function setUp() public {
        uint256 minDelay = 2 days;
        address proposer =
            vm.addr(uint256(keccak256(abi.encode("Proposer"))));
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));
        address admin =
            vm.addr(uint256(keccak256(abi.encode("Admin"))));

        address[] memory proposers = new address[](1);
        address[] memory executors = new address[](1);

        proposers[0] = proposer;
        executors[0] = executor;

        timeLock = new TimeLock(minDelay, proposers, executors, admin);
    }

    // #region test updateDelay.

    function testUpdateDelay() public {
        vm.expectRevert(ITimeLock.NotImplemented.selector);

        uint256 newDelay = 3 days;

        timeLock.updateDelay(newDelay);
    }

    // #endregion test updateDelay.
}
