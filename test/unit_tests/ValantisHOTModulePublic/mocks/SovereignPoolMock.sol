// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract SovereignPoolMock {
    address public token0;
    address public token1;

    uint256 public managerBalance0;
    uint256 public managerBalance1;

    uint256 public managerFeeBIPS;

    uint256 public reserves0;
    uint256 public reserves1;

    function setReserves(
        uint256 reserves0_,
        uint256 reserves1_
    ) external {
        reserves0 = reserves0_;
        reserves1 = reserves1_;
    }

    function setToken0AndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setManagesFees(
        uint256 managerBalance0_,
        uint256 managerBalance1_
    ) external {
        managerBalance0 = managerBalance0_;
        managerBalance1 = managerBalance1_;
    }

    function setPoolManagerFeeBips(uint256 poolManagerFeeBips_)
        external
    {
        managerFeeBIPS = poolManagerFeeBips_;
    }

    function claimPoolManagerFees(
        uint256,
        uint256
    )
        external
        returns (
            uint256 feePoolManager0Received,
            uint256 feePoolManager1Received
        )
    {
        feePoolManager0Received = managerBalance0;
        feePoolManager1Received = managerBalance1;
        if (managerBalance0 > 0) {
            IERC20(token0).transfer(msg.sender, managerBalance0);
        }

        if (managerBalance1 > 1) {
            IERC20(token1).transfer(msg.sender, managerBalance1);
        }
    }

    // #region view functions.

    function getPoolManagerFees()
        external
        view
        returns (uint256 poolManagerFee0, uint256 poolManagerFee1)
    {
        poolManagerFee0 = managerBalance0;
        poolManagerFee1 = managerBalance1;
    }

    function poolManagerFeeBips() external view returns (uint256) {
        return managerFeeBIPS;
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserves0, reserves1);
    }

    // #endregion view functions.
}
