// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {
    PermitBatchTransferFrom,
    PermitTransferFrom
} from "./SPermit2.sol";

struct AddLiquidityData {
    uint256 amount0Max;
    uint256 amount1Max;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 amountSharesMin;
    address vault;
    address receiver;
}

struct RemoveLiquidityData {
    uint256 burnAmount;
    uint256 amount0Min;
    uint256 amount1Min;
    address vault;
    address payable receiver; // not need to have receiveETH if reciever is payable.
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

struct RemoveLiquidityPermit2Data {
    RemoveLiquidityData removeData;
    PermitTransferFrom permit;
    bytes signature;
}

struct SwapAndAddPermit2Data {
    SwapAndAddData swapAndAddData;
    PermitBatchTransferFrom permit;
    bytes signature;
}
