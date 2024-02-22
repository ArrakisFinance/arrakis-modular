// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModulePrivate} from "../interfaces/IArrakisLPModulePrivate.sol";
import {ValantisModule} from "../abstracts/ValantisSOTModule.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract ValantisModulePrivate is ValantisModule, IArrakisLPModulePrivate {
    using SafeERC20 for IERC20Metadata;

    /// @notice deposit function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        // #region interactions.

        // #region get the tokens from the depositor.

        token0.safeTransferFrom(depositor_, address(this), amount0_);
        token1.safeTransferFrom(depositor_, address(this), amount1_);

        // #endregion get the tokens from the depositor.

        // #region increase allowance to alm.

        token0.safeIncreaseAllowance(address(alm), amount0_);
        token1.safeIncreaseAllowance(address(alm), amount1_);

        // #endregion increase allowance to alm.

        alm.depositLiquidity(amount0_, amount1_, 0, 0);

        // #endregion interactions.

        // #region assertions.

        if(token0.balanceOf(address(this)) - balance0 > 0)
            revert Deposit0();
        if(token1.balanceOf(address(this)) - balance1 > 0)
            revert Deposit1();

        // #endregion assertions.

        emit LogFund(depositor_, amount0_, amount1_);
    }
}