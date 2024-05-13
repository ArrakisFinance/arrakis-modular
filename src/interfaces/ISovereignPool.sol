// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ISovereignPool {
    function setPoolManagerFeeBips(uint256 poolManagerFeeBips_)
        external;

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

    function getPoolManagerFees()
        external
        view
        returns (uint256 poolManagerFee0, uint256 poolManagerFee1);

    function poolManagerFeeBips() external view returns (uint256);

    function getReserves() external view returns (uint256, uint256);

    // #endregion view functions.
}
