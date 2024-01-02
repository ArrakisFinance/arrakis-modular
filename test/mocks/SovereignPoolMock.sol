// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignPool} from "../../src/interfaces/ISovereignPool.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SovereignPoolMock is ISovereignPool {
    // #region Errors.

    error NotImplemented();
    error ManagerFeeBiggerThanMaxBips();

    // #endregion Errors.

    // #region constant.

    uint256 public constant MAX_BIPS = 10_000;

    // #endregion constant.

    // #region immutable.

    address public token0;
    address public token1;

    // #endregion immutable.

    // #region properties.

    address public poolManager;
    uint256 public poolManagerFeeBips;
    uint256 public feePoolManager0;
    uint256 public feePoolManager1;

    // #endregion properties.

    constructor(address token0_, address token1_, address poolManager_) {
        token0 = token0_;
        token1 = token1_;
        poolManager = poolManager_;
    }

    function setPoolManager(address manager_) external {
        revert NotImplemented();
    }

    function setPoolManagerFeeBips(uint256 poolManagerFeeBips_) external {
        poolManagerFeeBips = poolManagerFeeBips_;
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
    {
        IERC20(token0).transfer(poolManager, feePoolManager0);
        IERC20(token1).transfer(poolManager, feePoolManager1);
    }

    // #region mock functions.

    function setManagesFees(uint256 feePoolManager0_, uint256 feePoolManager1_) external {
        feePoolManager0 = feePoolManager0_;
        feePoolManager1 = feePoolManager1_;
    }

    // #endregion mock functions.
}
