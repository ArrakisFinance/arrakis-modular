// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IValantisHOTModulePrivate {
    /// @notice set HOT and initialize manager fees function.
    /// @param alm_ address of the valantis HOT ALM.
    function setALMAndManagerFees(address alm_) external;
}
