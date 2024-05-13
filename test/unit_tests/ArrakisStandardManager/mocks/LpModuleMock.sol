// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {NATIVE_COIN} from "../../../../src/constants/CArrakis.sol";
import {IOracleWrapper} from
    "../../../../src/interfaces/IOracleWrapper.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract LpModuleMock {
    uint256 public managerFeePIPS;
    IERC20 public token0;
    IERC20 public token1;
    address public manager;

    address public depositor;

    function setDepositor(address depositor_) external {
        depositor = depositor_;
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setToken0AndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setManagerFeePIPS(uint256 managerFeePIPS_) external {
        managerFeePIPS = managerFeePIPS_;
    }

    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        if (address(token0) == NATIVE_COIN) {
            amount0 = address(this).balance;
        } else {
            amount0 = token0.balanceOf(address(this));
        }
        if (address(token1) == NATIVE_COIN) {
            amount1 = address(this).balance;
        } else {
            amount1 = token1.balanceOf(address(this));
        }

        if (amount0 > 0) {
            if (address(token0) == NATIVE_COIN) {
                payable(manager).transfer(amount0);
            } else {
                token0.transfer(manager, amount0);
            }
        }

        if (amount1 > 0) {
            if (address(token1) == NATIVE_COIN) {
                payable(manager).transfer(amount1);
            } else {
                token1.transfer(manager, amount1);
            }
        }
    }

    ///@dev should only be used by USDC/WETH token pair.
    function firstRebalanceFunction(uint256 price0) external {
        uint8 decimals0 = IERC20Metadata(address(token0)).decimals();
        uint256 amount0 = token0.balanceOf(address(this));

        uint256 amount0ToSend = amount0 / 2;
        uint256 amount1ToGet =
            FullMath.mulDiv(amount0ToSend, price0, 10 ** decimals0);

        token0.transfer(depositor, amount0ToSend);
        token1.transferFrom(depositor, address(this), amount1ToGet);
    }

    ///@dev should only be used by USDC/WETH token pair.
    function secondRebalanceFunction() external {
        uint256 amount0 = token0.balanceOf(address(this));

        token0.transfer(depositor, amount0);
    }

    function thirdRebalanceFunction() external {
        revert("Something goes wrong");
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (address(token0) == NATIVE_COIN) {
            amount0 = address(this).balance;
        } else {
            amount0 = token0.balanceOf(address(this));
        }
        if (address(token1) == NATIVE_COIN) {
            amount1 = address(this).balance;
        } else {
            amount1 = token1.balanceOf(address(this));
        }
    }

    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {}
}
