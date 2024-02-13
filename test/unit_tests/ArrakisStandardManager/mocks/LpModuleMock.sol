// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LpModuleMock {
    uint256 public managerFeePIPS;
    IERC20 public token0;
    IERC20 public token1;
    address public manager;

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setToken0AndToken1(address token0_, address token1_) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setManagerFeePIPS(uint256 managerFeePIPS_) external {
        managerFeePIPS = managerFeePIPS_;
    }

    function withdrawManagerBalance() external returns(uint256 amount0, uint256 amount1) {
        amount0 = token0.balanceOf(address(this));
        amount1 = token1.balanceOf(address(this));

        if (amount0 > 0)
            token0.transfer(manager, amount0);

        if (amount1 > 0)
            token1.transfer(manager, amount1);
    }
}