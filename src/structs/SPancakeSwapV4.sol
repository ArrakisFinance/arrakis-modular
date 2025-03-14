// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

struct SwapPayload {
    bytes payload;
    address router;
    uint256 amountIn;
    uint256 expectedMinReturn;
    bool zeroForOne;
}