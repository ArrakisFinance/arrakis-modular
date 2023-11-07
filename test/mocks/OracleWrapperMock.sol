// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";

contract OracleWrapperMock is IOracleWrapper{
    uint256 public price0;
    uint256 public price1;

    function setPrice0(uint256 price0_) external {
        price0 = price0_;
    }

    function setPrice1(uint256 price1_) external {
        price1 = price1_;
    }

    function getPrice0() external view returns (uint256) {
        return price0;
    }

    function getPrice1() external view returns (uint256) {
        return price1;
    }
} 