// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IGuardian} from "../../../../src/interfaces/IGuardian.sol";

contract GuardianMock is IGuardian {
    address public pauser;

    function setPauser(address newPauser_) external {
        pauser = newPauser_;
    }
}