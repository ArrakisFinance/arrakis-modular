// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {ISovereignPool} from "../interfaces/ISovereignPool.sol";

contract SovereignPool is ISovereignPool {
    // #region errors.

    error NotImplemented();
    error OnlyPoolManager();

    // #endregion errors.

    uint256 public feePoolManager0;
    uint256 public feePoolManager1;
    uint256 public poolManagerFeeBips;
    address public poolManager;

    function setPoolManagerFeeBips(uint256 poolManagerFeeBips_) external {
        if (poolManager != msg.sender) revert OnlyPoolManager();
        poolManagerFeeBips = poolManagerFeeBips_;
    }

    function setPoolManager(address manager_) external {
        poolManager = manager_;
    }

    function claimPoolManagerFees(
        uint256 feeProtocol0Bips_,
        uint256 feeProtocol1Bips_
    )
        external
        returns (
            uint256 feePoolManager0Received,
            uint256 feePoolManager1Received
        )
    {}
}
