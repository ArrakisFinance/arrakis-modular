// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "../../src/interfaces/ICowSwapERC20.sol";
import {Trade} from "./Trade.sol";
import {GPv2Interaction} from "./GPv2Interaction.sol";

interface ICowSwapSettlement {
    function settle(
        IERC20[] calldata tokens,
        uint256[] calldata clearingPrices,
        Trade.Data[] calldata trades,
        GPv2Interaction.Data[][3] calldata interactions
    ) external;
}