// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IResolver} from "../../interfaces/IResolver.sol";
import {IUniV4StandardModuleResolver} from
    "../../interfaces/IUniV4StandardModuleResolver.sol";
import {IArrakisMetaVault} from
    "../../interfaces/IArrakisMetaVault.sol";
import {IUniV4StandardModule} from
    "../../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from "../../interfaces/IArrakisLPModule.sol";
import {UnderlyingPayload} from "../../structs/SUniswapV4.sol";
import {BASE, PIPS} from "../../constants/CArrakis.sol";
import {Range as PoolRange} from "../../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../../libraries/UnderlyingV4.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";

contract UniV4StandardModuleResolver is
    IResolver,
    IUniV4StandardModuleResolver
{
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // #region immutable variables.

    address public immutable poolManager;

    // #endregion immutable vairable.

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
        bool isInversed;
        uint256 buffer0;
        uint256 buffer1;

        UnderlyingPayload memory underlyingPayload;

        {
            PoolKey memory poolKey;
            address module;

            {
                module = address(IArrakisMetaVault(vault_).module());

                isInversed = IUniV4StandardModule(module).isInversed();

                (
                    poolKey.currency0,
                    poolKey.currency1,
                    poolKey.fee,
                    poolKey.tickSpacing,
                    poolKey.hooks
                ) = IUniV4StandardModule(module).poolKey();

                {
                    IUniV4StandardModule.Range[] memory _ranges =
                        IUniV4StandardModule(module).getRanges();

                    underlyingPayload.ranges =
                        new PoolRange[](_ranges.length);
                    uint160 sqrtPriceX96;

                    {
                        PoolId poolId = poolKey.toId();

                        (sqrtPriceX96,,,) =
                            IPoolManager(poolManager).getSlot0(poolId);
                    }

                    for (uint256 i; i < _ranges.length; i++) {
                        IUniV4StandardModule.Range memory range =
                            _ranges[i];
                        underlyingPayload.ranges[i] = PoolRange({
                            lowerTick: range.tickLower,
                            upperTick: range.tickUpper,
                            poolKey: poolKey
                        });

                        (uint256 b0, uint256 b1) =
                        _getBufferForOneWeiLiquidity(
                            range, sqrtPriceX96
                        );

                        buffer0 += b0;
                        buffer1 += b1;
                    }

                    buffer0 += 1;
                    buffer1 += 1;
                }

                (maxAmount0_, maxAmount1_) = isInversed
                    ? (maxAmount1_, maxAmount0_)
                    : (maxAmount0_, maxAmount1_);

                if (buffer0 >= maxAmount0_ || buffer1 >= maxAmount1_)
                {
                    revert MaxAmountsTooLow();
                }

                maxAmount0_ = maxAmount0_ - buffer0;
                maxAmount1_ = maxAmount1_ - buffer1;
            }
            {
                underlyingPayload.leftOver0 = poolKey
                    .currency0
                    .isAddressZero()
                    ? module.balance
                    : IERC20(Currency.unwrap(poolKey.currency0)).balanceOf(
                        module
                    );
                underlyingPayload.leftOver1 = IERC20(
                    Currency.unwrap(poolKey.currency1)
                ).balanceOf(module);

                underlyingPayload.poolManager =
                    IPoolManager(poolManager);
                underlyingPayload.self = module;
            }
        }

        uint256 totalSupply = IERC20(vault_).totalSupply();

        if (totalSupply > 0) {
            (uint256 current0, uint256 current1) = UnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, BASE);

            shareToMint = computeMintAmounts(
                current0,
                current1,
                totalSupply,
                maxAmount0_,
                maxAmount1_
            );
            uint256 proportion =
                FullMath.mulDiv(shareToMint, BASE, totalSupply);
            shareToMint = proportion * totalSupply / BASE;
            proportion = FullMath.mulDivRoundingUp(
                shareToMint, BASE, totalSupply
            );
            (amount0ToDeposit, amount1ToDeposit) = UnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, proportion);
        } else {
            (uint256 init0, uint256 init1) =
                IArrakisMetaVault(vault_).getInits();

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
            amount0ToDeposit > maxAmount0_ + buffer0
                || amount1ToDeposit > maxAmount1_ + buffer1
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

        IUniV4StandardModule module = IUniV4StandardModule(
            address(IArrakisMetaVault(vault_).module())
        );
        IUniV4StandardModule.Range[] memory ranges =
            module.getRanges();

        if (ranges.length == 0) {
            return (0, 0);
        }

        PoolKey memory poolKey;
        (
            poolKey.currency0,
            poolKey.currency1,
            poolKey.fee,
            poolKey.tickSpacing,
            poolKey.hooks
        ) = module.poolKey();
        PoolId poolId = poolKey.toId();

        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager).getSlot0(poolId);

        uint256 length = ranges.length;

        for (uint256 i; i < length; i++) {
            IUniV4StandardModule.Range memory range = ranges[i];
            (uint256 amt0, uint256 amt1) = computeBurnAmounts(
                range,
                poolId,
                address(module),
                sqrtPriceX96,
                proportion
            );

            amount0 += amt0;
            amount1 += amt1;
        }

        {
            if (poolKey.currency0 == CurrencyLibrary.ADDRESS_ZERO) {
                amount0 += FullMath.mulDiv(
                    address(module).balance, proportion, BASE
                );
            } else {
                amount0 += FullMath.mulDiv(
                    IERC20(Currency.unwrap(poolKey.currency0))
                        .balanceOf(address(module)),
                    proportion,
                    BASE
                );
            }

            amount1 += FullMath.mulDiv(
                IERC20(Currency.unwrap(poolKey.currency1)).balanceOf(
                    address(module)
                ),
                proportion,
                BASE
            );
        }

        if (module.isInversed()) {
            (amount0, amount1) = (amount1, amount0);
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

    /// @inheritdoc IUniV4StandardModuleResolver
    function computeBurnAmounts(
        IUniV4StandardModule.Range memory range_,
        PoolId poolId_,
        address module_,
        uint160 sqrtPriceX96_,
        uint256 proportion_
    ) public view returns (uint256 amount0, uint256 amount1) {
        Position.State memory positionState;
        (
            positionState.liquidity,
            positionState.feeGrowthInside0LastX128,
            positionState.feeGrowthInside1LastX128
        ) = IPoolManager(poolManager).getPositionInfo(
            poolId_, module_, range_.tickLower, range_.tickUpper, ""
        );

        {
            (
                uint256 feeGrowthInside0X128,
                uint256 feeGrowthInside1X128
            ) = IPoolManager(poolManager).getFeeGrowthInside(
                poolId_, range_.tickLower, range_.tickUpper
            );
            (amount0, amount1) = UnderlyingV4._getFeesOwned(
                positionState,
                feeGrowthInside0X128,
                feeGrowthInside1X128
            );

            amount0 = FullMath.mulDiv(amount0, proportion_, BASE);
            amount1 = FullMath.mulDiv(amount1, proportion_, BASE);
        }

        (uint256 amount0Current, uint256 amount1Current) =
        LiquidityAmounts.getAmountsForLiquidity(
            sqrtPriceX96_,
            TickMath.getSqrtPriceAtTick(range_.tickLower),
            TickMath.getSqrtPriceAtTick(range_.tickUpper),
            SafeCast.toUint128(
                FullMath.mulDiv(
                    positionState.liquidity, proportion_, BASE
                )
            )
        );

        amount0 += amount0Current;
        amount1 += amount1Current;
    }

    // #region internal functions.

    function _getBufferForOneWeiLiquidity(
        IUniV4StandardModule.Range memory range_,
        uint160 sqrtRatioX96_
    ) internal pure returns (uint256 buffer0, uint256 buffer1) {
        (buffer0, buffer1) = UnderlyingV4.getAmountsForDelta(
            sqrtRatioX96_,
            TickMath.getSqrtPriceAtTick(range_.tickLower),
            TickMath.getSqrtPriceAtTick(range_.tickUpper),
            int128(1)
        );
    }

    // #endregion internal functions.
}
