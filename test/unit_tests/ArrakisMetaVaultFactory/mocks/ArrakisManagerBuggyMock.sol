// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IManager} from "../../../../src/interfaces/IManager.sol";

contract ArrakisManagerBuggyMock is IManager {
    function initManagement(address) external {
        revert("Not Implemented");
    }

    function isManaged(address) external view returns (bool) {
        return false;
    }

    function getInitManagementSelector()
        external
        pure
        returns (bytes4)
    {
        return this.initManagement.selector;
    }
}
