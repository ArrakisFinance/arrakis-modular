// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IGuardian {

    // #region errors.

    error AddressZero();

    // #endregion errors.

    // #region events.

    event LogSetPauser(address oldPauser, address newPauser);

    // #endregion events.

    /// @notice function to get the address of the pauser of arrakis
    /// protocol.
    /// @return pauser address that can pause the arrakis protocol.
    function pauser() external view returns(address);

    /// @notice function to set the pauser of Arrakis protocol.
    function setPauser(address newPauser_) external;
}