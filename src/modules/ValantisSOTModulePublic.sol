// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModulePublic} from "../interfaces/IArrakisLPModulePublic.sol";
import {ValantisModule} from "../abstracts/ValantisSOTModule.sol";
import {PIPS} from "../constants/CArrakis.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ValantisModulePublic is ValantisModule, IArrakisLPModulePublic {
    using SafeERC20 for IERC20Metadata;

    /// @notice deposit function for public vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ percentage of portfolio position vault want to expand.
    /// @return amount0 amount of token0 needed to expand the portfolio by "proportion"
    /// percent.
    /// @return amount1 amount of token1 needed to expand the portfolio by "proportion"
    /// percent.
    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = alm.getReservesAtPrice(0);

            if (_amt0 == 0 && _amt1 == 0) {
                _amt0 = _init0;
                _amt1 = _init1;
            }

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        // #endregion effects.

        // #region interactions.

        // #region get the tokens from the depositor.

        token0.safeTransferFrom(depositor_, address(this), amount0);
        token1.safeTransferFrom(depositor_, address(this), amount1);

        // #endregion get the tokens from the depositor.

        // #region increase allowance to alm.

        token0.safeIncreaseAllowance(address(alm), amount0);
        token1.safeIncreaseAllowance(address(alm), amount1);

        // #endregion increase allowance to alm.

        alm.depositLiquidity(amount0, amount1, 0, 0);

        // #endregion interactions.

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }
}