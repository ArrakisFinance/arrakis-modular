// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVoter {
    function gauges(address pool) external view returns (address);
}