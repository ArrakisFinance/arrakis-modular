// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {BASE} from "../../../../src/constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract NewLpModuleBuggyMock {
    IERC20 public token0;
    IERC20 public token1;

    address public manager;

    uint256 public managerBalance0;
    uint256 public managerBalance1;

    uint256 public init0;
    uint256 public init1;

    // #region testing.

    uint256 public someValue;

    // #endregion testing.

    function deposit(
        address depositor_,
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1) {
        amount0 = FullMath.mulDiv(init0, proportion_, BASE);
        amount1 = FullMath.mulDiv(init1, proportion_, BASE);

        if (amount0 > 0) {
            token0.transferFrom(depositor_, address(this), amount0);
        }
        if (amount1 > 1) {
            token1.transferFrom(depositor_, address(this), amount1);
        }
    }

    function withdraw(
        address receiver_,
        uint256 proportion_
    ) external virtual returns (uint256 amount0, uint256 amount1) {
        amount0 = token0.balanceOf(address(this)) - managerBalance0;
        amount1 = token1.balanceOf(address(this)) - managerBalance1;

        amount0 = FullMath.mulDiv(amount0, proportion_, BASE);
        amount1 = FullMath.mulDiv(amount1, proportion_, BASE);

        if (amount0 > 0) token0.transfer(receiver_, amount0);
        if (amount1 > 0) token1.transfer(receiver_, amount1);
    }

    function getInits() external view returns (uint256, uint256) {
        return (init0, init1);
    }

    function setToken0AndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setInits(uint256 init0_, uint256 init1_) external {
        init0 = init0_;
        init1 = init1_;
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    function smallCall(uint256 someValue_) external {
        revert("Something go wrong");
    }

    function setManagerBalance0AndBalance1(
        uint256 managerBalance0_,
        uint256 managerBalance1_
    ) external {
        managerBalance0 = managerBalance0_;
        managerBalance1 = managerBalance1_;
    }

    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = managerBalance0;
        amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) token0.transfer(address(manager), amount0);
        if (amount1 > 0) token1.transfer(address(manager), amount1);
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = token0.balanceOf(address(this)) - managerBalance0;
        amount1 = token1.balanceOf(address(this)) - managerBalance1;
    }

    function totalUnderlyingAtPrice(uint160 priceX96_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 =
            (token0.balanceOf(address(this)) - managerBalance0) / 2;
        amount1 =
            (token1.balanceOf(address(this)) - managerBalance1) * 2;
    }
}
