// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisStandardManager} from
    "../../../../src/interfaces/IArrakisStandardManager.sol";
import {SetupParams} from "../../../../src/structs/SManager.sol";

contract ArrakisMetaVaultFactoryMock {
    address public manager;

    function setManager(address manager_) external {
        manager = manager_;
    }
}
