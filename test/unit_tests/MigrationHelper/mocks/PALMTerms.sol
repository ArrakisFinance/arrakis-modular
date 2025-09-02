// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {
    IPALMTerms,
    IArrakisV2
} from "../../../../src/interfaces/IPalmTerms.sol";

import {StdCheats} from "forge-std/StdCheats.sol";

contract PALMTermsMock is IPALMTerms, StdCheats {
    address public immutable token0;
    address public immutable token1;

    uint256 public amount0;
    uint256 public amount1;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    // #region mock functions.

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0 = amount0_;
        amount1 = amount1_;
    }

    // #endregion mock functions.

    function closeTerm(
        IArrakisV2 vault_,
        address to_,
        address newOwner_,
        address newManager_
    ) external {
        deal(token0, to_, amount0);
        deal(token1, to_, amount1);
    }
}
