// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IRouterSwapExecutor} from
    "./interfaces/IRouterSwapExecutor.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {SwapAndAddData} from "./structs/SRouter.sol";

import {
    IERC20,
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract RouterSwapExecutor is IRouterSwapExecutor {
    using Address for address payable;
    using SafeERC20 for IERC20;

    address public immutable router;
    address public immutable nativeToken;

    modifier onlyRouter() {
        if (msg.sender != router) {
            revert OnlyRouter(msg.sender, router);
        }
        _;
    }

    constructor(address router_, address nativeToken_) {
        if (router_ == address(0) || nativeToken_ == address(0)) {
            revert AddressZero();
        }
        router = router_;
        nativeToken = nativeToken_;
    }

    /// @notice function used to swap tokens.
    /// @param params_ struct containing all the informations for swapping.
    /// @return amount0Diff the difference in token0 amount before and after the swap.
    /// @return amount1Diff the difference in token1 amount before and after the swap.
    function swap(SwapAndAddData memory params_)
        external
        payable
        onlyRouter
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();
        uint256 balanceBefore;
        uint256 valueToSend;
        if (params_.swapData.zeroForOne) {
            if (token0 != nativeToken) {
                balanceBefore =
                    IERC20(token0).balanceOf(address(this));
                IERC20(token0).safeIncreaseAllowance(
                    params_.swapData.swapRouter,
                    params_.swapData.amountInSwap
                );
            } else {
                balanceBefore = address(this).balance;
                valueToSend = params_.swapData.amountInSwap;
            }
        } else {
            if (token1 != nativeToken) {
                balanceBefore =
                    IERC20(token1).balanceOf(address(this));
                IERC20(token1).safeIncreaseAllowance(
                    params_.swapData.swapRouter,
                    params_.swapData.amountInSwap
                );
            } else {
                balanceBefore = address(this).balance;
                valueToSend = params_.swapData.amountInSwap;
            }
        }
        (bool success,) = params_.swapData.swapRouter.call{
            value: valueToSend
        }(params_.swapData.swapPayload);
        if (!success) revert SwapCallFailed();

        uint256 balance0;
        uint256 balance1;
        if (token0 == nativeToken) {
            balance0 = address(this).balance;
            if (balance0 > 0) payable(router).sendValue(balance0);
        } else {
            balance0 = IERC20(token0).balanceOf(address(this));
            if (balance0 > 0) {
                IERC20(token0).safeTransfer(router, balance0);
            }
        }
        if (token1 == nativeToken) {
            balance1 = address(this).balance;
            if (balance1 > 0) payable(router).sendValue(balance1);
        } else {
            balance1 = IERC20(token1).balanceOf(address(this));
            if (balance1 > 0) {
                IERC20(token1).safeTransfer(router, balance1);
            }
        }
        if (params_.swapData.zeroForOne) {
            amount0Diff = balanceBefore - balance0;
            amount1Diff = balance1;
            if (amount1Diff < params_.swapData.amountOutSwap) {
                revert ReceivedBelowMinimum();
            }
        } else {
            amount0Diff = balance0;
            amount1Diff = balanceBefore - balance1;
            if (amount0Diff < params_.swapData.amountOutSwap) {
                revert ReceivedBelowMinimum();
            }
        }
    }

    receive() external payable {}
}
