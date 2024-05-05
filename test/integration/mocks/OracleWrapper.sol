// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";

contract OracleWrapper is IOracleWrapper {
    uint256 price0;
    uint256 price1;

    function getPrice0() external view returns (uint256) {
        return price0;
    }

    function getPrice1() external view returns (uint256) {
        return price1;
    }

    // #region mocks functions.

    function setPrice0(uint256 price0_) external {
        price0 = price0_;
    }

    function setPrice1(uint256 price1_) external {
        price1 = price1_;
    }

    // #endregion mocks functions.
}
