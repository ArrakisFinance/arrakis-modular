// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract PoolManagerMock {

    uint24 public fee;

    function updateDynamicLPFee(PoolKey memory key, uint24 newDynamicLPFee) external {
        fee = newDynamicLPFee;
    }
}