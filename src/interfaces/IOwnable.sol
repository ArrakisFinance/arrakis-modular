// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwnable {
    function owner() external view returns(address);
}