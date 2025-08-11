// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IResolver} from "../../interfaces/IResolver.sol";
import {IPancakeSwapV4StandardModuleResolver} from
    "../../interfaces/IPancakeSwapV4StandardModuleResolver.sol";
import {IArrakisMetaVault} from
    "../../interfaces/IArrakisMetaVault.sol";
import {IPancakeSwapV4StandardModule} from
    "../../interfaces/IPancakeSwapV4StandardModule.sol";
import {IArrakisLPModule} from "../../interfaces/IArrakisLPModule.sol";
import {UnderlyingPayload} from "../../structs/SPancakeSwapV4.sol";
import {BASE} from "../../constants/CArrakis.sol";
import {PancakeSwapV4} from "../../libraries/PancakeSwapV4.sol";
import {
    Range as PoolRange,
    GetFeesPayload,
    ComputeFeesPayload
} from "../../structs/SPancakeSwapV4.sol";
import {PancakeUnderlyingV4} from
    "../../libraries/PancakeUnderlyingV4.sol";

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {CLPosition} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/CLPosition.sol";
import {IVault} from "@pancakeswap/v4-core/src/interfaces/IVault.sol";
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";
import {TickMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/TickMath.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@pancakeswap/v4-core/src/types/PoolId.sol";
import {Tick} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/Tick.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

contract PancakeSwapV4StandardModuleResolver is
    IResolver,
    IPancakeSwapV4StandardModuleResolver
{
    using PoolIdLibrary for PoolKey;

    // #region immutable varaibles.

    address public immutable poolManager;

    // #endregion immutable variables.

    constructor(
        address poolManager_
    ) {
        if (poolManager_ == address(0)) {
            revert AddressZero();
        }

        poolManager = poolManager_;
    }

    /// @notice getMintAmounts used to get the shares we can mint from some max amounts.
    /// @param vault_ meta vault address.
    /// @param maxAmount0_ maximum amount of token0 user want to contribute.
    /// @param maxAmount1_ maximum amount of token1 user want to contribute.
    /// @return shareToMint maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.
    /// @return amount0ToDeposit amount of token0 user should deposit into the vault for minting 'shareToMint'.
    /// @return amount1ToDeposit amount of token1 user should deposit into the vault for minting 'shareToMint'.
    function getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        external
        view
        returns (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        )
    {
        uint256 totalSupply;
        address module;
        bool isInversed;

        UnderlyingPayload memory underlyingPayload;
        uint256 buffer;

        {
            PoolKey memory poolKey;
            PoolRange[] memory poolRanges;

            {
                totalSupply = IERC20(vault_).totalSupply();
                module = address(IArrakisMetaVault(vault_).module());

                isInversed =
                    IPancakeSwapV4StandardModule(module).isInversed();

                IPancakeSwapV4StandardModule.Range[] memory _ranges =
                    IPancakeSwapV4StandardModule(module).getRanges();

                buffer = 2 * _ranges.length;

                if (buffer >= maxAmount0_ || buffer >= maxAmount1_) {
                    revert MaxAmountsTooLow();
                }

                (maxAmount0_, maxAmount1_) = isInversed
                    ? (maxAmount1_, maxAmount0_)
                    : (maxAmount0_, maxAmount1_);

                maxAmount0_ =
                    maxAmount0_ > buffer ? maxAmount0_ - buffer : 0;
                maxAmount1_ =
                    maxAmount1_ > buffer ? maxAmount1_ - buffer : 0;

                poolRanges = new PoolRange[](_ranges.length);

                (
                    poolKey.currency0,
                    poolKey.currency1,
                    poolKey.hooks,
                    poolKey.poolManager,
                    poolKey.fee,
                    poolKey.parameters
                ) = IPancakeSwapV4StandardModule(module).poolKey();

                for (uint256 i; i < _ranges.length; i++) {
                    IPancakeSwapV4StandardModule.Range memory range =
                        _ranges[i];
                    poolRanges[i] = PoolRange({
                        lowerTick: range.tickLower,
                        upperTick: range.tickUpper,
                        poolKey: poolKey
                    });
                }
            }
            {
                uint256 leftOver0 = poolKey.currency0.isNative()
                    ? module.balance
                    : IERC20(Currency.unwrap(poolKey.currency0)).balanceOf(
                        module
                    );
                uint256 leftOver1 = IERC20(
                    Currency.unwrap(poolKey.currency1)
                ).balanceOf(module);

                underlyingPayload = UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: ICLPoolManager(poolManager),
                    self: module,
                    leftOver0: leftOver0,
                    leftOver1: leftOver1
                });
            }
        }

        if (totalSupply > 0) {
            (uint256 current0, uint256 current1) = PancakeUnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, BASE);

            shareToMint = computeMintAmounts(
                current0,
                current1,
                totalSupply,
                maxAmount0_,
                maxAmount1_
            );
            uint256 proportion = FullMath.mulDivRoundingUp(
                shareToMint, BASE, totalSupply
            );

            (amount0ToDeposit, amount1ToDeposit) = PancakeUnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, proportion);
        } else {
            (uint256 init0, uint256 init1) =
                IArrakisLPModule(module).getInits();

            (init0, init1) =
                isInversed ? (init1, init0) : (init0, init1);

            shareToMint = computeMintAmounts(
                init0, init1, BASE, maxAmount0_, maxAmount1_
            );

            // compute amounts owed to contract
            amount0ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init0, BASE);
            amount1ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init1, BASE);
        }

        if (
            amount0ToDeposit > maxAmount0_ + buffer
                || amount1ToDeposit > maxAmount1_ + buffer
        ) {
            revert AmountsOverMaxAmounts();
        }

        (amount0ToDeposit, amount1ToDeposit) = isInversed
            ? (amount1ToDeposit, amount0ToDeposit)
            : (amount0ToDeposit, amount1ToDeposit);
    }

    /// @inheritdoc IResolver
    function getBurnAmounts(
        address vault_,
        uint256 shares_
    ) external view returns (uint256 amount0, uint256 amount1) {
        if (vault_ == address(0)) {
            revert AddressZero();
        }

        if (shares_ == 0) {
            revert SharesZero();
        }

        uint256 proportion;

        {
            uint256 totalSupply = IERC20(vault_).totalSupply();

            if (totalSupply == 0) {
                revert TotalSupplyZero();
            }

            if (shares_ > totalSupply) {
                revert SharesOverTotalSupply();
            }

            proportion = FullMath.mulDiv(shares_, BASE, totalSupply);
        }

        IPancakeSwapV4StandardModule module =
        IPancakeSwapV4StandardModule(
            address(IArrakisMetaVault(vault_).module())
        );
        IPancakeSwapV4StandardModule.Range[] memory ranges =
            module.getRanges();

        if (ranges.length == 0) {
            return (0, 0);
        }

        PoolKey memory poolKey;
        (
            poolKey.currency0,
            poolKey.currency1,
            poolKey.hooks,
            poolKey.poolManager,
            poolKey.fee,
            poolKey.parameters
        ) = module.poolKey();
        PoolId poolId = poolKey.toId();

        (uint160 sqrtPriceX96, int24 tick,,) =
            ICLPoolManager(poolManager).getSlot0(poolId);

        uint256 length = ranges.length;

        for (uint256 i; i < length; i++) {
            IPancakeSwapV4StandardModule.Range memory range = ranges[i];
            (uint256 amt0, uint256 amt1) = computeBurnAmounts(
                range,
                poolId,
                address(module),
                sqrtPriceX96,
                tick,
                proportion
            );

            amount0 += amt0;
            amount1 += amt1;
        }
    }

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) public pure returns (uint256 mintAmount) {
        // compute proportional amount of tokens to mint
        if (current0_ == 0 && current1_ > 0) {
            mintAmount =
                FullMath.mulDiv(amount1Max_, totalSupply_, current1_);
        } else if (current1_ == 0 && current0_ > 0) {
            mintAmount =
                FullMath.mulDiv(amount0Max_, totalSupply_, current0_);
        } else if (current0_ > 0 && current1_ > 0) {
            uint256 amount0Mint =
                FullMath.mulDiv(amount0Max_, totalSupply_, current0_);
            uint256 amount1Mint =
                FullMath.mulDiv(amount1Max_, totalSupply_, current1_);

            if (amount0Mint == 0 || amount1Mint == 0) {
                revert MintZero();
            }

            mintAmount =
                amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }
    }

    function computeBurnAmounts(
        IPancakeSwapV4StandardModule.Range memory range_,
        PoolId poolId_,
        address module_,
        uint160 sqrtPriceX96_,
        int24 tick_,
        uint256 proportion_
    ) public view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;
        CLPosition.Info memory positionInfo;
        positionInfo = ICLPoolManager(poolManager).getPosition(
            poolId_, module_, range_.tickLower, range_.tickUpper, ""
        );

        (fee0, fee1) = _getFeesEarned(
            GetFeesPayload({
                feeGrowthInside0Last: positionInfo
                    .feeGrowthInside0LastX128,
                feeGrowthInside1Last: positionInfo
                    .feeGrowthInside1LastX128,
                poolId: poolId_,
                poolManager: ICLPoolManager(poolManager),
                liquidity: positionInfo.liquidity,
                tick: tick_,
                lowerTick: range_.tickLower,
                upperTick: range_.tickUpper
            })
        );

        fee0 = FullMath.mulDiv(fee0, proportion_, BASE);
        fee1 = FullMath.mulDiv(fee1, proportion_, BASE);

        uint128 liquidity = SafeCast.toUint128(
            FullMath.mulDiv(
                uint256(positionInfo.liquidity), proportion_, BASE
            )
        );

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96_,
            TickMath.getSqrtRatioAtTick(range_.tickLower),
            TickMath.getSqrtRatioAtTick(range_.tickUpper),
            liquidity
        );

        amount0 += fee0;
        amount1 += fee1;
    }

    // #region view internal/private functions.

    function _getFeesEarned(
        GetFeesPayload memory feeInfo_
    ) private view returns (uint256 fee0, uint256 fee1) {
        Tick.Info memory lower = feeInfo_.poolManager.getPoolTickInfo(
            feeInfo_.poolId, feeInfo_.lowerTick
        );
        Tick.Info memory upper = feeInfo_.poolManager.getPoolTickInfo(
            feeInfo_.poolId, feeInfo_.upperTick
        );

        ComputeFeesPayload memory payload = ComputeFeesPayload({
            feeGrowthInsideLast: feeInfo_.feeGrowthInside0Last,
            feeGrowthOutsideLower: lower.feeGrowthOutside0X128,
            feeGrowthOutsideUpper: upper.feeGrowthOutside0X128,
            feeGrowthGlobal: 0,
            poolId: feeInfo_.poolId,
            poolManager: feeInfo_.poolManager,
            liquidity: feeInfo_.liquidity,
            tick: feeInfo_.tick,
            lowerTick: feeInfo_.lowerTick,
            upperTick: feeInfo_.upperTick
        });

        (payload.feeGrowthGlobal,) =
            feeInfo_.poolManager.getFeeGrowthGlobals(feeInfo_.poolId);

        fee0 = _computeFeesEarned(payload);
        payload.feeGrowthInsideLast = feeInfo_.feeGrowthInside1Last;
        payload.feeGrowthOutsideLower = lower.feeGrowthOutside1X128;
        payload.feeGrowthOutsideUpper = upper.feeGrowthOutside1X128;
        (, payload.feeGrowthGlobal) =
            feeInfo_.poolManager.getFeeGrowthGlobals(feeInfo_.poolId);
        fee1 = _computeFeesEarned(payload);
    }

    function _computeFeesEarned(
        ComputeFeesPayload memory computeFees_
    ) private pure returns (uint256 fee) {
        unchecked {
            // calculate fee growth below
            uint256 feeGrowthBelow;
            if (computeFees_.tick >= computeFees_.lowerTick) {
                feeGrowthBelow = computeFees_.feeGrowthOutsideLower;
            } else {
                feeGrowthBelow = computeFees_.feeGrowthGlobal
                    - computeFees_.feeGrowthOutsideLower;
            }

            // calculate fee growth above
            uint256 feeGrowthAbove;
            if (computeFees_.tick < computeFees_.upperTick) {
                feeGrowthAbove = computeFees_.feeGrowthOutsideUpper;
            } else {
                feeGrowthAbove = computeFees_.feeGrowthGlobal
                    - computeFees_.feeGrowthOutsideUpper;
            }

            uint256 feeGrowthInside = computeFees_.feeGrowthGlobal
                - feeGrowthBelow - feeGrowthAbove;
            fee = FullMath.mulDiv(
                computeFees_.liquidity,
                feeGrowthInside - computeFees_.feeGrowthInsideLast,
                0x100000000000000000000000000000000
            );
        }
    }

    // #endregion view internal/private functions.
}
