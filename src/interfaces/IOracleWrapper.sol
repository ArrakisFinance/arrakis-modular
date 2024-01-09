// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOracleWrapper {
    function getPrice0() external view returns (uint256 price0);

    function getPrice1() external view returns (uint256 price1);
}