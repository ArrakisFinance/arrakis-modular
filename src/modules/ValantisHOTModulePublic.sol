// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";
import {ValantisModule} from "../abstracts/ValantisHOTModule.sol";
import {BASE} from "../constants/CArrakis.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ValantisModulePublic is
    ValantisModule,
    IArrakisLPModulePublic
{
    using SafeERC20 for IERC20Metadata;

    bool public notFirstDeposit;

    constructor(address guardian_) ValantisModule(guardian_) {}

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
            (uint256 _amt0, uint256 _amt1) = pool.getReserves();

            if (!notFirstDeposit) {
                if (_amt0 > 0 || _amt1 > 0) {
                    // #region send dust on pool to manager.

                    address manager = metaVault.manager();

                    alm.withdrawLiquidity(_amt0, _amt1, manager, 0, 0);

                    // #endregion send dust on pool to manager.
                }

                _amt0 = _init0;
                _amt1 = _init1;
                notFirstDeposit = true;
            }

            amount0 =
                FullMath.mulDivRoundingUp(proportion_, _amt0, BASE);
            amount1 =
                FullMath.mulDivRoundingUp(proportion_, _amt1, BASE);
        }

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

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ number of share needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    ) public override returns (uint256 amount0, uint256 amount1) {
        if (proportion_ == BASE) {
            notFirstDeposit = false;
        }
        return super.withdraw(receiver_, proportion_);
    }
}
