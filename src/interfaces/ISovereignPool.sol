// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ISovereignPool {
    function setPoolManagerFeeBips(uint256 poolManagerFeeBips_) external;

    function setPoolManager(address manager_) external;

    function claimPoolManagerFees(
        uint256 feeProtocol0Bips_,
        uint256 feeProtocol1Bips_
    )
        external
        returns (
            uint256 feePoolManager0Received,
            uint256 feePoolManager1Received
        );

    // #region view functions.

    function feePoolManager0() external view returns (uint256);

    function feePoolManager1() external view returns (uint256);

    function poolManagerFeeBips() external view returns (uint256);

    // #endregion view functions.
}
