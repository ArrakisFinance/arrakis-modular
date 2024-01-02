// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LpModuleMock} from "./LpModuleMock.sol";

contract ArrakisMetaVaultMock {
    address public immutable token0;
    address public immutable token1;

    LpModuleMock public module;
    address public manager;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function setModule(address module_, bytes[] calldata) external {
        module = LpModuleMock(module_);
    }

    // #region mock functions.

    function setManager(address manager_) public {
        manager = manager_;
    }

    // #endregion mock functions.
}
