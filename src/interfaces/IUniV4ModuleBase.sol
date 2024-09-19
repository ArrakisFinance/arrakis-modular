// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IUniV4ModuleBase {
    function poolKey() external view returns (PoolKey memory);
}