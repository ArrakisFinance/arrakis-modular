// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwnable {
    /// @notice function used to get the owner of this contract.
    function owner() external view returns (address);
}
