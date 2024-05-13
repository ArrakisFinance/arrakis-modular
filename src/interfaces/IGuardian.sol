// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IGuardian {
    // #region errors.

    error AddressZero();
    error SamePauser();

    // #endregion errors.

    // #region events.

    /// @notice event emitted when the pauser is set by the owner of the Guardian.
    /// @param oldPauser address of the previous pauser.
    /// @param newPauser address of the current pauser.
    event LogSetPauser(address oldPauser, address newPauser);

    // #endregion events.

    /// @notice function to get the address of the pauser of arrakis
    /// protocol.
    /// @return pauser address that can pause the arrakis protocol.
    function pauser() external view returns (address);

    /// @notice function to set the pauser of Arrakis protocol.
    function setPauser(address newPauser_) external;
}
