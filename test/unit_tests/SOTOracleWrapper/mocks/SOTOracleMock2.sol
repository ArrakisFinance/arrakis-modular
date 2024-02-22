// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";

contract SOTOracleMock2 {
    function getSqrtOraclePriceX96()
        external
        view
        returns (uint160 sqrtOraclePriceX96) {
            
        return type(uint160).max;
    }
}