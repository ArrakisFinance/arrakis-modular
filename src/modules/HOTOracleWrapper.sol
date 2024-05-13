// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IHOTOracle} from
    "@valantis-hot/contracts/interfaces/IHOTOracle.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract HOTOracleWrapper is IOracleWrapper {
    // #region immutable public variable.

    IHOTOracle public immutable oracle;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;

    // #endregion immutable public variable.

    constructor(address oracle_, uint8 decimals0_, uint8 decimals1_) {
        if (oracle_ == address(0)) {
            revert AddressZero();
        }
        if (decimals0_ == 0) {
            revert DecimalsToken0Zero();
        }
        if (decimals1_ == 0) {
            revert DecimalsToken1Zero();
        }

        oracle = IHOTOracle(oracle_);
        decimals0 = decimals0_;
        decimals1 = decimals1_;
    }

    function getPrice0() public view returns (uint256 price0) {
        uint256 priceX96 = oracle.getSqrtOraclePriceX96();

        if (priceX96 <= type(uint128).max) {
            price0 = FullMath.mulDiv(
                priceX96 * priceX96, 10 ** decimals0, 2 ** 192
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
                2 ** 192, 10 ** decimals1, priceX96 * priceX96
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
