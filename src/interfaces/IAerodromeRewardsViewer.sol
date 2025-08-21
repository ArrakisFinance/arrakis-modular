// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IAerodromeRewardsViewer {
    // #region errors.

    error AddressZero();
    error NotAerodromeModule();

    // #endregion errors.

    function getClaimableRewards(address vault_) external view returns (uint256);
    function AERO() external view returns (address);
    function id() external view returns (bytes32);
}
