// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IUniV3MultiPosition} from "../interfaces/IUniV3MultiPosition.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Underlying, Position, FullMath} from "../libraries/Underlying.sol";
import {Pool} from "../libraries/Pool.sol";
import {UnderlyingPayload, Range, Withdraw, RangeMintBurn} from "../structs/SUniswap.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {PIPS} from "../constants/CArrakis.sol";

error ProportionZero();
error WrongProportion();
error PoolZeroAddress(uint24 feeTier);
error NotValidRange();
error RangeDontExist();
error LessThanMinDeposit(uint256 deposit0, uint256 deposit1);
error LessThanMinWithdraw(uint256 withdraw0, uint256 withdraw1);
error OnlyMetaVault(address caller, address metaVault);
error ZeroLiquidity();

abstract contract UniV3MultiPosition is
    IArrakisLPModule,
    IUniV3MultiPosition,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // #region public properties.

    // #region immutable properties.

    IUniswapV3Factory public immutable factory;

    // #endregion immutanle properties.

    IArrakisMetaVault public metaVault;
    IERC20 public token0;
    IERC20 public token1;

    // #endregion public properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;

    Range[] internal _ranges;

    // #endregion internal properties.

    // #region modifier.

    modifier onlyVault() {
        if (msg.sender != address(metaVault))
            revert OnlyMetaVault(msg.sender, address(metaVault));
        _;
    }

    // #endregion modifier.

    constructor(IUniswapV3Factory factory_) {
        factory = factory_;
    }

    function deposit(
        uint256 proportion_
    )
        external
        nonReentrant
        onlyVault
        returns (uint256 amount0, uint256 amount1)
    {
        if (proportion_ == 0) revert ProportionZero();

        (amount0, amount1) = Underlying.totalUnderlyingForMint(
            UnderlyingPayload({
                ranges: _ranges,
                factory: factory,
                token0: address(token0),
                token1: address(token1),
                self: address(this)
            }),
            proportion_,
            address(metaVault)
        );

        if (amount0 == 0 && amount1 == 0) {
            uint256 init0M = _init0;
            uint256 init1M = _init1;

            amount0 = FullMath.mulDivRoundingUp(proportion_, init0M, PIPS);
            amount1 = FullMath.mulDivRoundingUp(proportion_, init1M, PIPS);

            /// @dev check ratio against small values that skew init ratio
            if (FullMath.mulDiv(proportion_, init0M, PIPS) == 0) {
                amount0 = 0;
            }
            if (FullMath.mulDiv(proportion_, init1M, PIPS) == 0) {
                amount1 = 0;
            }

            uint256 amount0P = init0M != 0
                ? FullMath.mulDiv(amount0, PIPS, init0M)
                : type(uint256).max;
            uint256 amount1P = init1M != 0
                ? FullMath.mulDiv(amount1, PIPS, init1M)
                : type(uint256).max;

            if ((amount0P < amount1P ? amount0P : amount1P) == proportion_)
                revert WrongProportion();
        }

        metaVault.moduleCallback(amount0, amount1);

        if (amount0 != 0 || amount1 != 0) {
            for (uint256 i; i < _ranges.length; i++) {
                Range memory range = _ranges[i];
                IUniswapV3Pool pool = IUniswapV3Pool(
                    factory.getPool(
                        address(token0),
                        address(token1),
                        range.feeTier
                    )
                );
                uint128 liquidity = Position.getLiquidityByRange(
                    pool,
                    address(this),
                    range.lowerTick,
                    range.upperTick
                );

                liquidity = SafeCast.toUint128(
                    FullMath.mulDiv(liquidity, proportion_, PIPS)
                );

                if (liquidity == 0) continue;

                pool.mint(
                    address(this),
                    range.lowerTick,
                    range.upperTick,
                    liquidity,
                    ""
                );
            }
        }

        emit LogDeposit(proportion_, amount0, amount1);
    }

    function withdraw(
        uint256 proportion_
    )
        external
        nonReentrant
        onlyVault
        returns (uint256 amount0, uint256 amount1)
    {
        if (proportion_ == 0) revert ProportionZero();

        Withdraw memory total;
        for (uint256 i; i < _ranges.length; i++) {
            Range memory range = _ranges[i];
            IUniswapV3Pool pool = IUniswapV3Pool(
                factory.getPool(address(token0), address(token1), range.feeTier)
            );
            uint128 liquidity = Position.getLiquidityByRange(
                pool,
                address(this),
                range.lowerTick,
                range.upperTick
            );

            liquidity = SafeCast.toUint128(
                FullMath.mulDiv(liquidity, proportion_, PIPS)
            );

            if (liquidity == 0) continue;

            Withdraw memory w = _withdraw(
                pool,
                range.lowerTick,
                range.upperTick,
                liquidity
            );

            total.fee0 += w.fee0;
            total.fee1 += w.fee1;

            total.burn0 += w.burn0;
            total.burn1 += w.burn1;
        }

        uint256 leftOver0 = token0.balanceOf(address(this)) - total.burn0;
        uint256 leftOver1 = token1.balanceOf(address(this)) - total.burn1;

        // the proportion of user balance.
        amount0 = FullMath.mulDiv(leftOver0, proportion_, PIPS);
        amount1 = FullMath.mulDiv(leftOver1, proportion_, PIPS);

        amount0 += total.burn0;
        amount1 += total.burn1;

        if (amount0 > 0) {
            token0.safeTransfer(address(metaVault), amount0);
        }

        if (amount1 > 0) {
            token1.safeTransfer(address(metaVault), amount1);
        }

        emit LogWithdraw(proportion_, amount0, amount1);
    }

    function mint(
        RangeMintBurn[] calldata ranges_,
        uint256 minDeposit0_,
        uint256 minDeposit1_
    )
        external
        nonReentrant
        onlyVault
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 len = ranges_.length;
        for (uint256 i; i < len; i++) {
            RangeMintBurn memory rangeMintBurn = ranges_[i];
            if (rangeMintBurn.liquidity == 0) revert ZeroLiquidity();
            (bool exists, ) = Position.rangeExists(
                _ranges,
                rangeMintBurn.range
            );

            address pool = factory.getPool(
                address(token0),
                address(token1),
                rangeMintBurn.range.feeTier
            );

            if (!exists) {
                // check that the pool exists on Uniswap V3.
                if (pool == address(0))
                    revert PoolZeroAddress(rangeMintBurn.range.feeTier);
                if (!Pool.validateTickSpacing(pool, rangeMintBurn.range))
                    revert NotValidRange();

                _ranges.push(rangeMintBurn.range);
            }

            (uint256 amt0, uint256 amt1) = IUniswapV3Pool(pool).mint(
                address(this),
                rangeMintBurn.range.lowerTick,
                rangeMintBurn.range.upperTick,
                rangeMintBurn.liquidity,
                ""
            );

            amount0 += amt0;
            amount1 += amt1;
        }

        if (amount0 >= minDeposit0_ || amount1 >= minDeposit1_)
            revert LessThanMinDeposit(amount0, amount1);

        emit LogMint(ranges_, amount0, amount1);
    }

    function burn(
        RangeMintBurn[] calldata ranges_,
        uint256 minBurn0_,
        uint256 minBurn1_
    ) external nonReentrant onlyVault returns (uint256 burn0, uint256 burn1) {
        Withdraw memory aggregator;
        uint256 len = ranges_.length;
        for (uint256 i; i < len; i++) {
            RangeMintBurn memory rangeMintBurn = ranges_[i];
            IUniswapV3Pool pool = IUniswapV3Pool(
                factory.getPool(
                    address(token0),
                    address(token1),
                    rangeMintBurn.range.feeTier
                )
            );

            uint128 liquidity = Position.getLiquidityByRange(
                pool,
                address(this),
                rangeMintBurn.range.lowerTick,
                rangeMintBurn.range.upperTick
            );

            if (liquidity == 0) continue;

            uint128 liquidityToWithdraw;

            if (rangeMintBurn.liquidity == type(uint128).max)
                liquidityToWithdraw = liquidity;
            else liquidityToWithdraw = rangeMintBurn.liquidity;

            Withdraw memory w = _withdraw(
                pool,
                rangeMintBurn.range.lowerTick,
                rangeMintBurn.range.upperTick,
                liquidityToWithdraw
            );

            if (liquidityToWithdraw == liquidity) {
                (bool exists, uint256 index) = Position.rangeExists(
                    _ranges,
                    rangeMintBurn.range
                );
                if (!exists) revert RangeDontExist();

                _ranges[index] = _ranges[_ranges.length - 1];
                _ranges.pop();
            }

            aggregator.burn0 += w.burn0;
            aggregator.burn1 += w.burn1;

            aggregator.fee0 += w.fee0;
            aggregator.fee1 += w.fee1;
        }

        burn0 = aggregator.burn0 + aggregator.fee0;
        burn1 = aggregator.burn1 + aggregator.fee1;

        if (aggregator.burn0 < minBurn0_ || aggregator.burn1 < minBurn1_)
            revert LessThanMinWithdraw(aggregator.burn0, aggregator.burn1);

        emit LogBurn(ranges_, burn0, burn1);
    }

    function collect()
        external
        nonReentrant
        onlyVault
        returns (uint256 collects0, uint256 collects1)
    {
        (collects0, collects1) = _collectFeesOnPools();

        emit LogCollect(collects0, collects1);
    }

    // #region view functions.

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return (_init0, _init1);
    }

    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1, , ) = Underlying.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: _ranges,
                factory: factory,
                token0: address(token0),
                token1: address(token1),
                self: address(this)
            })
        );
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1, , ) = Underlying.totalUnderlyingAtPriceWithFees(
            UnderlyingPayload({
                ranges: _ranges,
                factory: factory,
                token0: address(token0),
                token1: address(token1),
                self: address(this)
            }),
            priceX96_
        );
    }

    function ranges() external view returns (Range[] memory) {
        return _ranges;
    }

    // #endregion view functions.

    // #region internal functions.

    function _withdraw(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_,
        uint128 liquidity_
    ) internal returns (Withdraw memory w) {
        (w.burn0, w.burn1) = pool_.burn(lowerTick_, upperTick_, liquidity_);

        (uint256 collect0, uint256 collect1) = _collectFees(
            pool_,
            lowerTick_,
            upperTick_
        );

        w.fee0 = collect0 - w.burn0;
        w.fee1 = collect1 - w.burn1;
    }

    function _collectFeesOnPools()
        internal
        returns (uint256 collects0, uint256 collects1)
    {
        uint256 len = _ranges.length;
        for (uint256 i; i < len; i++) {
            Range memory range = _ranges[i];
            IUniswapV3Pool pool = IUniswapV3Pool(
                factory.getPool(address(token0), address(token1), range.feeTier)
            );

            /// @dev to update the position and collect fees.
            pool.burn(range.lowerTick, range.upperTick, 0);

            (uint256 collect0, uint256 collect1) = _collectFees(
                pool,
                range.lowerTick,
                range.upperTick
            );

            collects0 += collect0;
            collects1 += collect1;
        }
    }

    function _collectFees(
        IUniswapV3Pool pool_,
        int24 lowerTick_,
        int24 upperTick_
    ) internal returns (uint256 collect0, uint256 collect1) {
        (collect0, collect1) = pool_.collect(
            address(this),
            lowerTick_,
            upperTick_,
            type(uint128).max,
            type(uint128).max
        );
    }

    function _isRangeExist(
        int24 lowerTick_,
        int24 upperTick_,
        uint24 feeTier_
    ) internal view returns (bool rangeExist) {
        uint256 len = _ranges.length;
        for (uint256 i; i < len; i++) {
            Range memory range = _ranges[i];
            if (
                range.lowerTick == lowerTick_ &&
                range.upperTick == upperTick_ &&
                range.feeTier == feeTier_
            ) return true;
        }
    }

    // #endregion internal functions.
}
