// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracleWrapper} from
    "../../../../src/interfaces/IOracleWrapper.sol";

contract OracleMock is IOracleWrapper {
    function getPrice0() external view returns (uint256 price0) {
        price0 = 0.0005 ether;
    }

    function getPrice1() external view returns (uint256 price1) {
        price1 = 2000e6;
    }
}
