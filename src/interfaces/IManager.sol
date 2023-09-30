// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IManager {
    function getFee(uint24 proportion) external view returns (uint256 fee0, uint256 fee1);
}