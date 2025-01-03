// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IArrakisLPModuleID {
    /// @notice function used to get module id.
    function id() external view returns (bytes32);
}
