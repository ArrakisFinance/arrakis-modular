// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";
import {PancakeSwapV3StandardModule} from
    "../abstracts/PancakeSwapV3StandardModule.sol";
import {IPancakeSwapV3StandardModule} from
    "../interfaces/IPancakeSwapV3StandardModule.sol";
import {BASE} from "../constants/CArrakis.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {Range} from "../structs/SUniswapV3.sol";
import {UnderlyingV3} from "../libraries/UnderlyingV3.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

/// @notice this module can only set pancake v3 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
contract PancakeSwapV3StandardModulePublic is
    PancakeSwapV3StandardModule,
    IArrakisLPModulePublic
{
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    // #region errors.

    // #endregion errors.

    // #region public constants.

    /// @dev id = keccak256(abi.encode("PancakeSwapV3StandardModulePublic"))
    bytes32 public constant id =
        0xf8a84b2e3e22d069766d4756d362bc5c6eb85d74765bf4feeb8c017f9e8c7938;

    // #endregion public constants.

    bool public notFirstDeposit;

    constructor(
        address guardian_,
        address factory_,
        address distributor_
    ) PancakeSwapV3StandardModule(guardian_, factory_, distributor_) {}

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ proportion of position needed to be add.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (depositor_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        // #endregion checks.

        uint256 total0;
        uint256 total1;

        // Calculate deposit amounts based on current underlying values

        if (!notFirstDeposit) {
            (total0, total1) = (_init0, _init1);
            notFirstDeposit = true;
        } else {
            (total0, total1) = totalUnderlying();
        }

        amount0 = FullMath.mulDivRoundingUp(total0, proportion_, BASE);
        amount1 = FullMath.mulDivRoundingUp(total1, proportion_, BASE);

        // Transfer tokens from depositor to this contract
        if (amount0 > 0) {
            token0.safeTransferFrom(
                depositor_, address(this), amount0
            );
        }

        if (amount1 > 0) {
            token1.safeTransferFrom(
                depositor_, address(this), amount1
            );
        }

        // Expand active ranges by proportion
        _expandRangesByProportion(proportion_);

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

    function initializePosition(
        bytes calldata
    ) external override onlyMetaVault {
        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        if (balance0 > 0 || balance1 > 0) {
            notFirstDeposit = true;
        }
    }

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ proportion of position needed to be withdrawn.
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

    // #region internal functions.

    /// @notice Expand active ranges by proportion by adding liquidity to existing positions
    /// @param proportion_ proportion to expand the ranges by
    function _expandRangesByProportion(
        uint256 proportion_
    ) internal {
        // Get current ranges
        Range[] memory ranges = getRanges();
        uint256 length = ranges.length;

        if (length == 0) {
            // If no ranges exist, this is the first deposit
            // The manager will need to set up ranges via rebalance
            return;
        }

        // For each active range, add liquidity proportionally
        for (uint256 i; i < length; i++) {
            Range memory range = ranges[i];
            bytes32 positionId = UnderlyingV3.getPositionId(
                address(this), range.lowerTick, range.upperTick
            );

            if (_activeRanges[positionId]) {
                // Get current liquidity for this position
                (uint128 currentLiquidity,,,,) =
                    IUniswapV3Pool(pool).positions(positionId);

                if (currentLiquidity > 0) {
                    // Calculate additional liquidity to add
                    uint128 additionalLiquidity = uint128(
                        FullMath.mulDiv(
                            uint256(currentLiquidity),
                            proportion_,
                            BASE
                        )
                    );

                    if (additionalLiquidity > 0) {
                        // Mint additional liquidity to the position
                        IUniswapV3Pool(pool).mint(
                            address(this),
                            range.lowerTick,
                            range.upperTick,
                            additionalLiquidity,
                            ""
                        );
                    }
                }
            }
        }
    }

    // #endregion internal functions.
}
