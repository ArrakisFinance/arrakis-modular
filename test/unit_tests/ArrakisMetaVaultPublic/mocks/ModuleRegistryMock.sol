// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LpModuleMock} from "./LpModuleMock.sol";
import {NewLpModuleBuggyMock} from "./NewLpModuleBuggyMock.sol";

contract ModuleRegistryMock {
    function createModule(
        address,
        address,
        bytes calldata data_
    ) external returns (address) {
        if (data_.length == 0) {
            return address(new LpModuleMock());
        }
        return (address(new NewLpModuleBuggyMock()));
    }
}
