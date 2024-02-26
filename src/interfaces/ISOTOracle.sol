// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./AggregatorV3Interface.sol";

interface ISOTOracle {
    // #region view functions.

    function token0Decimals() external view returns (uint8);

    function token1Decimals() external view returns (uint8);

    function token0Base() external view returns (uint256);

    function token1Base() external view returns (uint256);

    function maxOracleUpdateDuration()
        external
        view
        returns (uint32);

    function feedToken0()
        external
        view
        returns (AggregatorV3Interface);

    function feedToken1()
        external
        view
        returns (AggregatorV3Interface);

    // #endregion view functions.

    function getSqrtOraclePriceX96()
        external
        view
        returns (uint160 sqrtOraclePriceX96);
}
