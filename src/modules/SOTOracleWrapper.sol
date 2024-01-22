// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {ISOTOracle} from "../interfaces/ISOTOracle.sol";

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

contract SOTOracleWrapper is IOracleWrapper {
    // #region immutable public variable.

    ISOTOracle public immutable oracle;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;

    // #endregion immutable public variable.

    constructor(address oracle_) {
        oracle = ISOTOracle(oracle_);
    }

    function getPrice0() public view returns (uint256 price0) {
        uint256 priceX96 = oracle.getSqrtOraclePriceX96();

        if (priceX96 <= type(uint128).max) {
            price0 = FullMath.mulDiv(
                priceX96 * priceX96,
                10 ** decimals0,
                2 ** 192
            );
        } else {
            price0 = FullMath.mulDiv(
                FullMath.mulDiv(priceX96, priceX96, 1 << 64),
                10 ** decimals0,
                1 << 128
            );
        }
    }

    function getPrice1() public view returns (uint256 price1) {
        uint256 priceX96 = oracle.getSqrtOraclePriceX96();

        if (priceX96 <= type(uint128).max) {
            price1 = FullMath.mulDiv(
                2 ** 192,
                10 ** decimals1,
                priceX96 * priceX96
            );
        } else {
            price1 = FullMath.mulDiv(
                1 << 128,
                10 ** decimals1,
                FullMath.mulDiv(priceX96, priceX96, 1 << 64)
            );
        }
    }
}
