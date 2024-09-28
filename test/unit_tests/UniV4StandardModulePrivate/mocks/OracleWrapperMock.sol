// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IOracleWrapper} from
    "../../../../src/interfaces/IOracleWrapper.sol";

contract OracleMock is IOracleWrapper {
    uint256 internal _price0;
    uint256 internal _price1;

    // #region mock functions.

    function setPrice0(uint256 price0_) external {
        _price0 = price0_;
    }

    function setPrice1(uint256 price1_) external {
        _price1 = price1_;
    }

    // #endregion mock functions.

    function getPrice0() external view returns (uint256) {
        return _price0;
    }

    function getPrice1() external view returns (uint256) {
        return _price1;
    }
}
