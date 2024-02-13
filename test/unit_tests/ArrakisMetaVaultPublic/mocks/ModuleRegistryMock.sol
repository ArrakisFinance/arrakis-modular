// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LpModuleMock} from "./LpModuleMock.sol";

contract ModuleRegistryMock {
    function createModule(
        address,
        address,
        bytes calldata
    ) external returns(address) {
        return address(new LpModuleMock());
    }
}
