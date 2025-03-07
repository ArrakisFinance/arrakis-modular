// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisV2} from "../../../../src/interfaces/IArrakisV2.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArrakisV2Mock is IArrakisV2 {
    IERC20 public token0;
    IERC20 public token1;

    // #region mock functions.

    function setTokens(IERC20 token0_, IERC20 token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    // #endregion mock functions.
}
