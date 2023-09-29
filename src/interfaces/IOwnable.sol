// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IOwnable {
    function transferOwnership(address newOwner) external payable;
    function renounceOwnership() external payable;

    function owner() external view returns (address result);
}