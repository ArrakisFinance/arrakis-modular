// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IVoter {
    function killGauge(address _gauge) external;
    function gauges(address pool) external view returns (address);
    function isAlive(address gauge) external view returns (bool);
    function emergencyCouncil() external view returns (address);
}