// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {PIPS} from "../../src/constants/CArrakis.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract LpModuleMock {
    IERC20 public token0;
    IERC20 public token1;

    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint256 public managerFeePIPS;
    address public manager;

    uint256 public init0;
    uint256 public init1;

    constructor(address token0_, address token1_, address manager_) {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        manager = manager_;
    }

    function setManagerFeePIPS(uint256 managerFeePIPS_) external {
        managerFeePIPS = managerFeePIPS_;
    }

    function withdrawManagerBalance() external returns (uint256, uint256) {
        uint256 _managerBalance0 = managerBalance0;
        uint256 _managerBalance1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        token0.transfer(manager, _managerBalance0);
        token1.transfer(manager, _managerBalance1);

        return (_managerBalance1, _managerBalance1);
    }

    function withdraw(
        address receiver_,
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1) {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        balance0 = balance0 - managerBalance0;
        balance1 = balance1 - managerBalance1;

        amount0 = FullMath.mulDiv(balance0, proportion_, PIPS);
        amount1 = FullMath.mulDiv(balance1, proportion_, PIPS);

        // #region send the corresponding proportion to receiver.

        token0.transfer(receiver_, amount0);
        token1.transfer(receiver_, amount1);

        // #endregion send the corresponding proportion to receiver.
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = token0.balanceOf(address(this)) - managerBalance0;
        amount1 = token1.balanceOf(address(this)) - managerBalance1;
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {

        amount0 = token0.balanceOf(address(this)) - managerBalance0;
        amount1 = token1.balanceOf(address(this)) - managerBalance1;

        uint256 currentPriceX96 = FullMath.mulDiv(amount0, amount1, 1e18);

        amount0 = FullMath.mulDiv(
            amount0,
            priceX96_,
            currentPriceX96
        );
        amount1 = FullMath.mulDiv(
            amount1,
            currentPriceX96,
            priceX96_
        );
    }

    function getInits() external view returns (uint256, uint256) {
        return (init0, init1);
    }

    // #region mock functions.

    function setManagerBalances(uint256 amount0_, uint256 amount1_) public {
        managerBalance0 = amount0_;
        managerBalance1 = amount1_;
    }

    function setInits(uint256 init0_, uint256 init1_) public {
        init0 = init0_;
        init1 = init1_;
    }

    // #endregion mock functions.
}
