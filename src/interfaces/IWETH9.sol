// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256 wad) external;
}
