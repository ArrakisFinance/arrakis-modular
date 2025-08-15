// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {PancakeSwapV3StandardModule} from
    "../abstracts/PancakeSwapV3StandardModule.sol";
import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";
import {IUniswapV3PoolVariant} from
    "../interfaces/IUniswapV3PoolVariant.sol";
import {ModifyPosition} from "../structs/SUniswapV3.sol";
import {MintReturnValues} from "../structs/SPancakeSwapV3.sol";
import {PIPS, BASE} from "../constants/CArrakis.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract PancakeSwapV3StandardModulePublic is
    PancakeSwapV3StandardModule,
    IArrakisLPModulePublic
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.UintSet;

    // #region public constants.

    /// @dev id = keccak256(abi.encode("PancakeSwapV3StandardModulePublic"))
    bytes32 public constant id =
        0x918c66e50fd8ae37316bc2160d5f23b3f5d59ccd1972c9a515dc2f8ac22875b6;

    // #endregion public constants.

    bool public notFirstDeposit;

    constructor(
        address guardian_,
        address nftPositionManager_,
        address factory_,
        address cake_,
        address masterChefV3_
    )
        PancakeSwapV3StandardModule(
            guardian_,
            nftPositionManager_,
            factory_,
            cake_,
            masterChefV3_
        )
    {}

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

        if (proportion_ == 0) revert ProportionZero();
        if (msg.value > 0) revert NativeCoinNotAllowed();

        // #endregion checks.

        uint256 total0;
        uint256 total1;

        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(pool).slot0();

        if (!notFirstDeposit) {
            (total0, total1) = (_init0, _init1);
            notFirstDeposit = true;
        } else {
            (total0, total1) = _totalUnderlying(sqrtPriceX96);
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
        _expandRangesByProportion(proportion_, sqrtPriceX96);

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

    /// @notice Expand by proportion existing positions
    /// @param proportion_ proportion to expand positions by
    function _expandRangesByProportion(
        uint256 proportion_,
        uint160 sqrtPriceX96_
    ) internal {
        // Get current tokenIds
        uint256[] memory tIds = _tokenIds.values();

        uint256 length = tIds.length;

        if (length == 0) {
            // If no position exist, this is the first deposit
            // The manager will need to set up ranges via rebalance
            return;
        }

        uint256 fee0;
        uint256 fee1;
        uint256 cakeAmountCollected;
        MintReturnValues memory mintReturnValues;

        // For each positions, add liquidity proportionally
        for (uint256 i; i < length;) {
            uint256 tokenId = tIds[i];

            ModifyPosition memory modifyPosition = ModifyPosition({
                tokenId: tokenId,
                proportion: proportion_
            });

            (
                mintReturnValues.amount0,
                mintReturnValues.amount1,
                mintReturnValues.fee0,
                mintReturnValues.fee1,
                mintReturnValues.cakeCo
            ) = _increaseLiquidity(modifyPosition, sqrtPriceX96_);

            fee0 += mintReturnValues.fee0;
            fee1 += mintReturnValues.fee1;
            cakeAmountCollected += mintReturnValues.cakeCo;

            unchecked {
                i += 1;
            }
        }

        // #region manager cake rewards.

        uint256 _managerFeePIPS = managerFeePIPS;

        if (cakeAmountCollected > 0) {
            _cakeManagerBalance += FullMath.mulDiv(
                cakeAmountCollected, _managerFeePIPS, PIPS
            );
        }

        // #endregion manager cake rewards.

        // #region manager fees.

        {
            address manager = metaVault.manager();

            if (fee0 > 0) {
                uint256 managerFee0 =
                    FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
                token0.safeTransfer(manager, managerFee0);
            }
            if (fee1 > 0) {
                uint256 managerFee1 =
                    FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
                token1.safeTransfer(manager, managerFee1);
            }
        }

        // #endregion manager fees.
    }

    // #endregion internal functions.
}
