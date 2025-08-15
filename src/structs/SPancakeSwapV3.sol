// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {ModifyPosition, SwapPayload} from "./SUniswapV3.sol";
import {SwapPayload} from "./SUniswapV3.sol";
import {INonfungiblePositionManagerPancake} from
    "../interfaces/INonfungiblePositionManagerPancake.sol";

struct RebalanceParams {
    ModifyPosition[] decreasePositions;
    ModifyPosition[] increasePositions;
    SwapPayload swapPayload;
    INonfungiblePositionManagerPancake.MintParams[] mintParams;
    uint256 minBurn0;
    uint256 minBurn1;
    uint256 minDeposit0;
    uint256 minDeposit1;
}

struct MintReturnValues {
    uint256 amount0;
    uint256 amount1;
    uint256 fee0;
    uint256 fee1;
    uint256 cakeCo;
}