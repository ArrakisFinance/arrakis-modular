// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {
    PermitBatchTransferFrom,
    PermitTransferFrom
} from "./SPermit2.sol";

struct AddLiquidityData {
    uint256 amount0;
    uint256 amount1;
    address vault;
}

struct SwapData {
    bytes swapPayload;
    uint256 amountInSwap;
    uint256 amountOutSwap;
    address swapRouter;
    bool zeroForOne;
}

struct SwapAndAddData {
    SwapData swapData;
    AddLiquidityData addData;
}

struct AddLiquidityPermit2Data {
    AddLiquidityData addData;
    PermitBatchTransferFrom permit;
    bytes signature;
}

struct SwapAndAddPermit2Data {
    SwapAndAddData swapAndAddData;
    PermitBatchTransferFrom permit;
    bytes signature;
}