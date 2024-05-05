// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

interface ISOTOracle {
    function getSqrtOraclePriceX96()
        external
        view
        returns (uint160 sqrtOraclePriceX96);
}
