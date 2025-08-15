// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracleWrapper} from
    "../../../../src/interfaces/IOracleWrapper.sol";

contract OracleWrapperMock is IOracleWrapper {
    uint256 private _price0 = 1e18; // Default 1:1 price
    uint256 private _price1 = 1e18;

    function setPrice0(uint256 price_) external {
        _price0 = price_;
    }

    function setPrice1(uint256 price_) external {
        _price1 = price_;
    }

    function getPrice0() external view override returns (uint256) {
        return _price0;
    }

    function getPrice1() external view override returns (uint256) {
        return _price1;
    }
}