// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IValantisSOTModulePrivate {
    /// @notice set SOT and initialize manager fees function.
    /// @param alm_ address of the valantis SOT ALM.
    function setALMAndManagerFees(address alm_) external;
}
