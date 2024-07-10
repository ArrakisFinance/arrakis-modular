// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";

import {PIPS, BASE, NATIVE_COIN} from "../constants/CArrakis.sol";
import {
    UnderlyingPayload,
    Range as PoolRange
} from "../structs/SUniswapV4.sol";

import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IERC6909Claims} from
    "@uniswap/v4-core/src/interfaces/external/IERC6909Claims.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IUnlockCallback} from
    "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";

/// @notice this module can only set uni v4 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
contract UniV4StandardModule is
    ReentrancyGuard,
    Pausable,
    IArrakisLPModule,
    IUniV4StandardModule,
    IUnlockCallback
{
    using SafeERC20 for IERC20Metadata;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using Hooks for IHooks;
    using Address for address payable;
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;

    // #region immutable properties.

    IPoolManager public immutable poolManager;
    IArrakisMetaVault public immutable metaVault;
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;
    bool public immutable isInversed;

    // #endregion immutable properties

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    // #region public properties.

    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint256 public managerFeePIPS;

    PoolKey public poolKey;

    // #endregion public properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;

    Range[] internal _ranges;
    mapping(bytes32 => bool) internal _activeRanges;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyManager() {
        address manager = metaVault.manager();
        if (manager != msg.sender) {
            revert OnlyManager(msg.sender, manager);
        }
        _;
    }

    modifier onlyMetaVault() {
        address metaVaultAddr = address(metaVault);
        if (metaVaultAddr != msg.sender) {
            revert OnlyMetaVault(msg.sender, metaVaultAddr);
        }
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    // #endregion modifiers.

    constructor(
        address poolManager_,
        PoolKey memory poolKey_,
        address metaVault_,
        address token0_,
        address token1_,
        uint256 init0_,
        uint256 init1_,
        address guardian_,
        bool isInversed_
    ) {
        // #region checks.

        if (poolManager_ == address(0)) revert AddressZero();
        if (metaVault_ == address(0)) revert AddressZero();
        if (token0_ == address(0)) revert AddressZero();
        if (token1_ == address(0)) revert AddressZero();
        if (guardian_ == address(0)) revert AddressZero();
        if (token0_ >= token1_) revert Token0GteToken1();

        _checkTokens(poolKey_, token0_, token1_, isInversed_);

        if (
            poolKey_.hooks.hasPermission(
                Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            )
                || poolKey_.hooks.hasPermission(
                    Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                )
        ) revert NoModifyLiquidityHooks();

        /// @dev check if the pool is initialized.
        PoolId poolId = poolKey_.toId();
        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager_).getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        // #endregion checks.

        poolManager = IPoolManager(poolManager_);
        poolKey = poolKey_;
        metaVault = IArrakisMetaVault(metaVault_);
        token0 = IERC20Metadata(token0_);
        token1 = IERC20Metadata(token1_);

        _guardian = guardian_;
        isInversed = isInversed_;

        if (isInversed_) {
            _init1 = init0_;
            _init0 = init1_;
        } else {
            _init0 = init0_;
            _init1 = init1_;
        }
    }

    // #region guardian functions.

    /// @notice function used to pause the module.
    /// @dev only callable by guardian
    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    /// @notice function used to unpause the module.
    /// @dev only callable by guardian
    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function initializePosition(bytes calldata data_) external {}

    // #region only manager functions.

    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_
    ) external onlyManager nonReentrant {
        address _token0 = address(token0);
        address _token1 = address(token1);

        _checkTokens(poolKey_, _token0, _token1, isInversed);

        if (
            poolKey_.fee == poolKey.fee
                && poolKey_.tickSpacing == poolKey.tickSpacing
                && address(poolKey_.hooks) == address(poolKey.hooks)
        ) revert SamePool();

        if (
            poolKey_.hooks.hasPermission(
                Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            )
                || poolKey_.hooks.hasPermission(
                    Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                )
        ) revert NoModifyLiquidityHooks();

        /// @dev check if the pool is initialized.
        PoolId poolId = poolKey_.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        // #region remove any remaining liquidity on the previous pool.

        // #region get liquidities and remove.

        uint256 length = _ranges.length;

        PoolId currentPoolId = poolKey.toId();
        LiquidityRange[] memory liquidityRanges =
            new LiquidityRange[](length);

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            /// @dev salt will be emty string on the module.
            bytes32 positionKey = keccak256(
                abi.encodePacked(
                    address(this),
                    range.tickLower,
                    range.tickUpper,
                    ""
                )
            );
            (uint128 liquidityToRemove,,) = poolManager
                .getPositionInfo(currentPoolId, positionKey);

            liquidityRanges[i] = LiquidityRange({
                liquidity: -SafeCast.toInt128(
                    SafeCast.toInt256(uint256(liquidityToRemove))
                ),
                range: Range({
                    tickLower: range.tickLower,
                    tickUpper: range.tickUpper
                })
            });
        }

        _internalRebalance(liquidityRanges);

        // #endregion get liquidities and remove.

        // #endregion remove any remaining liquidity on the previous pool.

        // #region set PoolKey.

        poolKey = poolKey_;

        // #endregion set PoolKey.

        // #region add liquidity on the new pool.

        if (liquidityRanges_.length > 0) {
            _internalRebalance(liquidityRanges_);
        }

        // #endregion add liquidity on the new pool.

        emit LogSetPool(poolKey, poolKey = poolKey_);
    }

    // #endregion only manager functions.

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ number of share needed to be add.
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
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (depositor_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        // #endregion checks.

        bytes memory data =
            abi.encode(0, abi.encode(depositor_, proportion_));

        bytes memory result = poolManager.unlock(data);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        // emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ number of share needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    )
        external
        onlyMetaVault
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        if (proportion_ > BASE) revert ProportionGtBASE();

        // #endregion checks.

        bytes memory data =
            abi.encode(1, abi.encode(receiver_, proportion_));

        bytes memory result = poolManager.unlock(data);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    function rebalance(LiquidityRange[] memory liquidityRanges_)
        public
        onlyManager
        nonReentrant
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        )
    {
        _internalRebalance(liquidityRanges_);
    }

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 length = _ranges.length;

        LiquidityRange[] memory liquidityRanges =
            new LiquidityRange[](length);

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];

            liquidityRanges[i] = LiquidityRange({
                liquidity: 0,
                range: Range({
                    tickLower: range.tickLower,
                    tickUpper: range.tickUpper
                })
            });
        }
        bytes memory data = abi.encode(2, abi.encode(liquidityRanges));

        bytes memory result = poolManager.unlock(data);

        (,,,, amount0, amount1) = abi.decode(
            result,
            (uint256, uint256, uint256, uint256, uint256, uint256)
        );
    }

    /// @notice function used to set manager fees.
    /// @param newFeePIPS_ new fee that will be applied.
    function setManagerFeePIPS(uint256 newFeePIPS_)
        external
        onlyManager
    {
        uint256 _managerFeePIPS = managerFeePIPS;
        if (_managerFeePIPS == newFeePIPS_) revert SameManagerFee();
        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);
        managerFeePIPS = newFeePIPS_;
        emit LogSetManagerFeePIPS(_managerFeePIPS, newFeePIPS_);
    }

    /// @notice Called by the pool manager on `msg.sender` when a lock is acquired
    /// @param data_ The data that was passed to the call to lock
    /// @return result data that you want to be returned from the lock call
    function unlockCallback(bytes calldata data_)
        external
        virtual
        returns (bytes memory)
    {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }

        /// @dev use data to do specific action.

        (uint256 action, bytes memory data) =
            abi.decode(data_, (uint256, bytes));

        if (action == 0) {
            (address depositor, uint256 proportion) =
                abi.decode(data, (address, uint256));
            return _deposit(depositor, proportion);
        }
        if (action == 1) {
            (address receiver, uint256 proportion) =
                abi.decode(data, (address, uint256));
            return _withdraw(receiver, proportion);
        }
        if (action == 2) {
            LiquidityRange[] memory liquidityRanges =
                abi.decode(data, (LiquidityRange[]));
            return _rebalance(liquidityRanges);
        }

        revert CallBackNotSupported();
    }

    // receive() external payable {

    // }

    // #region view functions.

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    /// @notice function used to get the list of active ranges.
    /// @return ranges active ranges
    function getRanges()
        external
        view
        returns (Range[] memory ranges)
    {
        ranges = _ranges;
    }

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {
        if (isInversed) {
            return (_init1, _init0);
        }
        return (_init0, _init1);
    }

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        PoolRange[] memory poolRanges = _getPoolRanges(_ranges.length);

        (address _token0, address _token1) = _getTokens();

        uint256 fees0;
        uint256 fees1;

        (amount0, amount1, fees0, fees1) = UnderlyingV4.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            })
        );

        amount0 = amount0 - FullMath.mulDiv(fees0, managerFeePIPS, PIPS);
        amount1 = amount1 - FullMath.mulDiv(fees1, managerFeePIPS, PIPS);

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(uint160 priceX96_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 length = _ranges.length;

        PoolRange[] memory poolRanges = new PoolRange[](length);

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            poolRanges[i] = PoolRange({
                lowerTick: range.tickLower,
                upperTick: range.tickUpper,
                poolKey: poolKey
            });
        }

        (address _token0, address _token1) = _getTokens();

        (amount0, amount1,,) = UnderlyingV4
            .totalUnderlyingAtPriceWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            }),
            priceX96_
        );

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// @param oracle_ oracle that will used to check internal state.
    /// @param maxDeviation_ maximum deviation allowed.
    /// rebalance can happen.
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {
        // check if pool current price is not too far from oracle price.

        (address _token0, address _token1) = _getTokens();

        uint8 token0Decimals = _token0 == address(0)
            ? 18
            : IERC20Metadata(_token0).decimals();
        uint8 token1Decimals = _token1 == address(0)
            ? 18
            : IERC20Metadata(_token1).decimals();

        // #region compute pool price.

        PoolId poolId = poolKey.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        uint256 poolPrice;

        if (sqrtPriceX96 <= type(uint128).max) {
            poolPrice = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** token0Decimals,
                1 << 192
            );
        } else {
            poolPrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** token0Decimals,
                1 << 128
            );
        }

        // #endregion compute pool price.

        // #region get oracle price.

        uint256 oraclePrice =
            isInversed ? oracle_.getPrice1() : oracle_.getPrice0();

        // #endregion get oracle price.

        // #region check deviation.

        uint256 deviation = FullMath.mulDiv(
            FullMath.mulDiv(
                poolPrice > oraclePrice
                    ? poolPrice - oraclePrice
                    : oraclePrice - poolPrice,
                10 ** token1Decimals,
                poolPrice
            ),
            PIPS,
            10 ** token1Decimals
        );

        // #endregion check deviation.

        if (deviation > maxDeviation_) revert OverMaxDeviation();
    }

    // #endregion view functions.

    // #region internal functions.

    function _deposit(
        address depositor_,
        uint256 proportion_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        PoolId poolId = _poolKey.toId();
        uint256 length = _ranges.length;
        address manager = metaVault.manager();

        (address _token0, address _token1) = _getTokens();

        // #region get liquidity for each positions and mint.

        // #region fees computations.

        uint256 fee0;
        uint256 fee1;
        {
            PoolRange[] memory poolRanges = _getPoolRanges(length);

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager,
                    token0: _token0,
                    token1: _token1,
                    self: address(this)
                })
            );
        }

        // #endregion fees computations.

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];

            Position.Info memory info = poolManager.getPosition(
                poolId,
                address(this),
                range.tickLower,
                range.tickUpper,
                ""
            );

            /// @dev no need to rounding up because uni v4 should do it during minting.
            uint256 liquidity = FullMath.mulDiv(
                uint256(info.liquidity), proportion_, BASE
            );

            if (liquidity > 0) {
                poolManager.modifyLiquidity(
                    _poolKey,
                    IPoolManager.ModifyLiquidityParams({
                        tickLower: range.tickLower,
                        tickUpper: range.tickUpper,
                        liquidityDelta: SafeCast.toInt256(liquidity),
                        salt: bytes32(0)
                    }),
                    ""
                );
            }
        }

        // #endregion get liquidity for each positions and mint.
        {
            // #region send manager fees.

            uint256 managerFee0 =
                FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
            uint256 managerFee1 =
                FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

            if (managerFee0 > 0) {
                poolManager.take(
                    _poolKey.currency0, manager, managerFee0
                );
            }
            if (managerFee1 > 0) {
                poolManager.take(
                    _poolKey.currency1, manager, managerFee1
                );
            }

            if (managerFee0 > 0 || managerFee1 > 0) {
                emit LogWithdrawManagerBalance(
                    manager, managerFee0, managerFee1
                );
            }

            // #endregion send manager fees.

            // #region mint extra collected fees.

            uint256 extraCollect0 = fee0 - managerFee0;
            uint256 extraCollect1 = fee1 - managerFee1;

            if (extraCollect0 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency0),
                    extraCollect0
                );
            }
            if (extraCollect1 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency1),
                    extraCollect1
                );
            }

            // #endregion mint extra collected fees.
        }
        {
            // #region get how much left over we have on poolManager and mint.

            (, uint256 leftOver0,, uint256 leftOver1) =
                _get1155Balances();

            if (length == 0 && leftOver0 == 0 && leftOver1 == 0) {
                leftOver0 = _init0;
                leftOver1 = _init1;
            }

            // rounding up during mint only.
            uint256 leftOver0ToMint = FullMath.mulDivRoundingUp(
                leftOver0, proportion_, BASE
            );
            uint256 leftOver1ToMint = FullMath.mulDivRoundingUp(
                leftOver1, proportion_, BASE
            );

            if (leftOver0ToMint > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency0),
                    leftOver0ToMint
                );
            }

            if (leftOver1ToMint > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency1),
                    leftOver1ToMint
                );
            }

            // #endregion get how much left over we have on poolManager and mint.
        }
        // #region get how much we should settle with poolManager.

        (uint256 amount0, uint256 amount1) = _checkCurrencyBalances();

        // #endregion get how much we should settle with poolManager.

        if (amount0 > 0) {
            poolManager.sync(_poolKey.currency0);
            if (_poolKey.currency0.isNative()) {
                /// @dev no need to use Address lib for PoolManager.
                poolManager.settle{value: amount0}(_poolKey.currency0);
                uint256 ethLeftBalance = address(this).balance;
                if (ethLeftBalance > 0) {
                    payable(depositor_).sendValue(ethLeftBalance);
                }
            } else {
                IERC20Metadata(_token0).safeTransferFrom(
                    depositor_, address(poolManager), amount0
                );
                poolManager.settle(_poolKey.currency0);
            }
        }

        if (amount1 > 0) {
            /// @dev currency1 cannot be native coin because address(0).
            poolManager.sync(_poolKey.currency1);

            IERC20Metadata(_token1).safeTransferFrom(
                depositor_, address(poolManager), amount1
            );
            poolManager.settle(_poolKey.currency1);
        }

        // #region settle.

        // #endregion settle.

        return isInversed
            ? abi.encode(amount1, amount0)
            : abi.encode(amount0, amount1);
    }

    function _withdraw(
        address receiver_,
        uint256 proportion_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        PoolId poolId = _poolKey.toId();
        uint256 length = _ranges.length;

        // #region fees computations.

        uint256 fee0;
        uint256 fee1;
        {
            PoolRange[] memory poolRanges = _getPoolRanges(length);

            (address _token0, address _token1) = _getTokens();

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager,
                    token0: _token0,
                    token1: _token1,
                    self: address(this)
                })
            );
        }

        // #endregion fees computations.

        // #region get liquidity for each positions and burn.

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];

            Position.Info memory info = poolManager.getPosition(
                poolId,
                address(this),
                range.tickLower,
                range.tickUpper,
                ""
            );

            /// @dev multiply -1 because we will remove liquidity.
            uint256 liquidity = FullMath.mulDiv(
                uint256(info.liquidity), proportion_, BASE
            );

            if (liquidity == uint256(info.liquidity)) {
                bytes32 positionId = keccak256(
                    abi.encode(
                        poolId, range.tickLower, range.tickUpper
                    )
                );
                _activeRanges[positionId] = false;
                (uint256 indexToRemove, uint256 l) =
                    _getRangeIndex(range.tickLower, range.tickUpper);

                _ranges[indexToRemove] = _ranges[l - 1];
                _ranges.pop();
            }

            if (liquidity > 0) {
                poolManager.modifyLiquidity(
                    _poolKey,
                    IPoolManager.ModifyLiquidityParams({
                        liquidityDelta: -1 * SafeCast.toInt256(liquidity),
                        tickLower: range.tickLower,
                        tickUpper: range.tickUpper,
                        salt: bytes32(0)
                    }),
                    ""
                );
            }
        }

        // #endregion get liquidity for each positions and burn.

        // #region get how much left over we have on poolManager and burn.

        {
            (, uint256 leftOver0,, uint256 leftOver1) =
                _get1155Balances();

            // rounding up during mint only
            uint256 leftOver0ToBurn =
                FullMath.mulDiv(leftOver0, proportion_, BASE);
            uint256 leftOver1ToBurn =
                FullMath.mulDiv(leftOver1, proportion_, BASE);

            if (leftOver0ToBurn > 0) {
                poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency0),
                    leftOver0ToBurn
                );
            }
            if (leftOver1ToBurn > 0) {
                poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency1),
                    leftOver1ToBurn
                );
            }
        }

        // #endregion get how much left over we have on poolManager and mint.

        uint256 amount0 = SafeCast.toUint256(
            poolManager.currencyDelta(
                address(this), _poolKey.currency0
            )
        );

        uint256 amount1 = SafeCast.toUint256(
            poolManager.currencyDelta(
                address(this), _poolKey.currency1
            )
        );

        // #region take and send token to receiver.

        /// @dev if receiver is a smart contract, the sm should implement receive
        /// fallback function.

        {
            address manager = metaVault.manager();

            // #region manager fees.
            uint256 fee0ToWithdraw;
            uint256 fee1ToWithdraw;
            {
                uint256 managerFee0 =
                    FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
                uint256 managerFee1 =
                    FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

                fee0ToWithdraw = FullMath.mulDiv(
                    fee0 - managerFee0, proportion_, BASE
                );
                fee1ToWithdraw = FullMath.mulDiv(
                    fee1 - managerFee1, proportion_, BASE
                );

                // #endregion manager fees.

                poolManager.take(
                    _poolKey.currency0, manager, managerFee0
                );
                poolManager.take(
                    _poolKey.currency1, manager, managerFee1
                );

                if (managerFee0 > 0 || managerFee1 > 0) {
                    emit LogWithdrawManagerBalance(
                        manager, managerFee0, managerFee1
                    );
                }
            }

            amount0 = amount0 - fee0 + fee0ToWithdraw;
            amount1 = amount1 - fee1 + fee1ToWithdraw;

            poolManager.take(_poolKey.currency0, receiver_, amount0);
            poolManager.take(_poolKey.currency1, receiver_, amount1);
        }

        // #endregion take and send token to receiver.

        result = isInversed
            ? abi.encode(amount1, amount0)
            : abi.encode(amount0, amount1);

        // #region mint extra collected fees.

        {
            (amount0, amount1) = _checkCurrencyBalances();

            poolManager.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency0),
                amount0
            );
            poolManager.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency1),
                amount1
            );
        }

        // #endregion mint extra collected fees.
    }

    function _internalRebalance(
        LiquidityRange[] memory liquidityRanges_
    )
        internal
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        )
    {
        bytes memory data =
            abi.encode(2, abi.encode(liquidityRanges_));

        bytes memory result = poolManager.unlock(data);

        (amount0Minted, amount1Minted, amount0Burned, amount1Burned,,)
        = abi.decode(
            result,
            (uint256, uint256, uint256, uint256, uint256, uint256)
        );

        emit LogRebalance(
            liquidityRanges_,
            amount0Minted,
            amount1Minted,
            amount0Burned,
            amount1Burned
        );
    }

    function _rebalance(LiquidityRange[] memory liquidityRanges_)
        internal
        returns (bytes memory result)
    {
        PoolKey memory _poolKey = poolKey;
        PoolId poolId = _poolKey.toId();
        uint256 length = liquidityRanges_.length;
        address manager = metaVault.manager();
        // #region fees computations.

        uint256 fee0;
        uint256 fee1;
        {
            PoolRange[] memory poolRanges =
                _getPoolRanges(_ranges.length);

            (address _token0, address _token1) = _getTokens();

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager,
                    token0: _token0,
                    token1: _token1,
                    self: address(this)
                })
            );
        }

        // #endregion fees computations.

        // #region add liquidities.

        uint256 amount0Minted;
        uint256 amount1Minted;
        uint256 amount0Burned;
        uint256 amount1Burned;

        for (uint256 i; i < length; i++) {
            LiquidityRange memory lrange = liquidityRanges_[i];
            if (lrange.liquidity > 0) {
                (uint256 amt0, uint256 amt1) = _addLiquidity(
                    _poolKey,
                    poolId,
                    SafeCast.toUint128(
                        SafeCast.toUint256(lrange.liquidity)
                    ),
                    lrange.range.tickLower,
                    lrange.range.tickUpper
                );

                amount0Minted += amt0;
                amount1Minted += amt1;
            } else if (lrange.liquidity < 0) {
                (uint256 amt0, uint256 amt1) = _removeLiquidity(
                    _poolKey,
                    poolId,
                    SafeCast.toUint128(
                        SafeCast.toUint256(-lrange.liquidity)
                    ),
                    lrange.range.tickLower,
                    lrange.range.tickUpper
                );

                amount0Burned += amt0;
                amount1Burned += amt1;
            } else {
                _collectFee(
                    _poolKey,
                    poolId,
                    lrange.range.tickLower,
                    lrange.range.tickUpper
                );
            }
        }
        // #endregion add liquidities.

        // #region collect and send fees to manager.
        uint256 managerFee0;
        uint256 managerFee1;
        {
            managerFee0 = FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
            managerFee1 = FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

            if (managerFee0 > 0) {
                poolManager.take(
                    _poolKey.currency0, manager, managerFee0
                );
            }
            if (managerFee1 > 0) {
                poolManager.take(
                    _poolKey.currency1, manager, managerFee1
                );
            }

            if (managerFee0 > 0 || managerFee1 > 0) {
                emit LogWithdrawManagerBalance(
                    manager, managerFee0, managerFee1
                );
            }
        }

        {
            // #region get how much left over we have on poolManager and mint.

            int256 amt0 = poolManager.currencyDelta(
                address(this), poolKey.currency0
            );

            int256 amt1 = poolManager.currencyDelta(
                address(this), poolKey.currency1
            );

            if (amt0 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency0),
                    SafeCast.toUint256(amt0)
                );
            } else if (amt0 < 0) {
                poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency0),
                    SafeCast.toUint256(-amt0)
                );
            }
            if (amt1 > 0) {
                poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency1),
                    SafeCast.toUint256(amt1)
                );
            } else if (amt1 < 0) {
                poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency1),
                    SafeCast.toUint256(-amt1)
                );
            }

            // #endregion get how much left over we have on poolManager and mint.
        }

        // #endregion collect and sent fees to manager.

        return isInversed
            ? abi.encode(
                amount1Minted,
                amount0Minted,
                amount1Burned,
                amount0Burned,
                managerFee1,
                managerFee0
            )
            : abi.encode(
                amount0Minted,
                amount1Minted,
                amount0Burned,
                amount1Burned,
                managerFee0,
                managerFee1
            );
    }

    function _collectFee(
        PoolKey memory poolKey_,
        PoolId poolId_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal {
        _checkTicks(tickLower_, tickUpper_);

        bytes32 positionId =
            keccak256(abi.encode(poolId_, tickLower_, tickUpper_));

        if (!_activeRanges[positionId]) {
            revert RangeShouldBeActive(tickLower_, tickUpper_);
        }

        poolManager.modifyLiquidity(
            poolKey_,
            IPoolManager.ModifyLiquidityParams({
                liquidityDelta: 0,
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                salt: bytes32(0)
            }),
            ""
        );
    }

    function _addLiquidity(
        PoolKey memory poolKey_,
        PoolId poolId_,
        uint128 liquidityToAdd_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal returns (uint256 amount0, uint256 amount1) {
        // #region checks.

        if (liquidityToAdd_ == 0) revert LiquidityToAddEqZero();

        _checkTicks(tickLower_, tickUpper_);

        // #endregion checks.

        // #region effects.

        bytes32 positionId =
            keccak256(abi.encode(poolId_, tickLower_, tickUpper_));
        if (!_activeRanges[positionId]) {
            _ranges.push(
                Range({tickLower: tickLower_, tickUpper: tickUpper_})
            );
            _activeRanges[positionId] = true;
        }

        // #endregion effects.
        // #region interactions.

        poolManager.modifyLiquidity(
            poolKey_,
            IPoolManager.ModifyLiquidityParams({
                liquidityDelta: SafeCast.toInt256(
                    uint256(liquidityToAdd_)
                ),
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                salt: bytes32(0)
            }),
            ""
        );

        (amount0, amount1) = _checkCurrencyBalances();

        if (amount0 > 0) {
            poolManager.burn(
                address(this),
                CurrencyLibrary.toId(poolKey_.currency0),
                amount0
            );
        }
        if (amount1 > 0) {
            poolManager.burn(
                address(this),
                CurrencyLibrary.toId(poolKey_.currency1),
                amount1
            );
        }

        // #endregion interactions.

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    function _removeLiquidity(
        PoolKey memory poolKey_,
        PoolId poolId_,
        uint128 liquidityToRemove_,
        int24 tickLower_,
        int24 tickUpper_
    ) internal returns (uint256 amount0, uint256 amount1) {
        // #region checks.

        if (liquidityToRemove_ == 0) revert LiquidityToRemoveEqZero();

        //#endregion checks.

        // #region get liqudity.

        Position.Info memory info = poolManager.getPosition(
            poolId_, address(this), tickLower_, tickUpper_, ""
        );

        // #endregion get liquidity.

        // #region effects.

        bytes32 positionId =
            keccak256(abi.encode(poolId_, tickLower_, tickUpper_));

        if (!_activeRanges[positionId]) {
            revert RangeShouldBeActive(tickLower_, tickUpper_);
        }

        if (liquidityToRemove_ > info.liquidity) revert OverBurning();

        if (liquidityToRemove_ == info.liquidity) {
            _activeRanges[positionId] = false;
            (uint256 indexToRemove, uint256 length) =
                _getRangeIndex(tickLower_, tickUpper_);

            _ranges[indexToRemove] = _ranges[length - 1];
            _ranges.pop();
        }

        // #endregion effects.

        // #region interactions.

        poolManager.modifyLiquidity(
            poolKey_,
            IPoolManager.ModifyLiquidityParams({
                liquidityDelta: -SafeCast.toInt256(uint256(liquidityToRemove_)),
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                salt: bytes32(0)
            }),
            ""
        );

        amount0 = SafeCast.toUint256(
            poolManager.currencyDelta(
                address(this), poolKey.currency0
            )
        );

        amount1 = SafeCast.toUint256(
            poolManager.currencyDelta(
                address(this), poolKey.currency1
            )
        );

        if (amount0 > 0) {
            poolManager.mint(
                address(this),
                CurrencyLibrary.toId(poolKey_.currency0),
                amount0
            );
        }
        if (amount1 > 0) {
            poolManager.mint(
                address(this),
                CurrencyLibrary.toId(poolKey_.currency1),
                amount1
            );
        }

        // #endregion interactions.

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    // #region view functions.

    function _get1155Balances()
        internal
        view
        returns (
            uint256 currency0Id,
            uint256 leftOver0,
            uint256 currency1Id,
            uint256 leftOver1
        )
    {
        currency0Id = CurrencyLibrary.toId(poolKey.currency0);
        leftOver0 = IERC6909Claims(address(poolManager)).balanceOf(
            address(this), currency0Id
        );

        currency1Id = CurrencyLibrary.toId(poolKey.currency1);
        leftOver1 = IERC6909Claims(address(poolManager)).balanceOf(
            address(this), currency1Id
        );
    }

    function _checkCurrencyBalances()
        internal
        view
        returns (uint256, uint256)
    {
        int256 currency0BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency0
        );
        if (currency0BalanceRaw > 0) revert InvalidCurrencyDelta();
        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw);
        int256 currency1BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency1
        );
        if (currency1BalanceRaw > 0) revert InvalidCurrencyDelta();
        uint256 currency1Balance =
            SafeCast.toUint256(-currency1BalanceRaw);

        return (currency0Balance, currency1Balance);
    }

    function _getRangeIndex(
        int24 tickLower_,
        int24 tickUpper_
    ) internal view returns (uint256, uint256) {
        uint256 length = _ranges.length;

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            if (
                range.tickLower == tickLower_
                    && range.tickUpper == tickUpper_
            ) {
                return (i, length);
            }
        }

        revert RangeNotFound();
    }

    function _getPoolRanges(uint256 length_)
        internal
        view
        returns (PoolRange[] memory poolRanges)
    {
        poolRanges = new PoolRange[](length_);
        for (uint256 i; i < length_; i++) {
            Range memory range = _ranges[i];
            poolRanges[i] = PoolRange({
                lowerTick: range.tickLower,
                upperTick: range.tickUpper,
                poolKey: poolKey
            });
        }
    }

    function _checkTicks(
        int24 tickLower_,
        int24 tickUpper_
    ) internal pure {
        if (tickLower_ >= tickUpper_) {
            revert TicksMisordered(tickLower_, tickUpper_);
        }
        if (tickLower_ < TickMath.MIN_TICK) {
            revert TickLowerOutOfBounds(tickLower_);
        }
        if (tickUpper_ > TickMath.MAX_TICK) {
            revert TickUpperOutOfBounds(tickUpper_);
        }
    }

    function _getTokens()
        internal
        view
        returns (address token0, address token1)
    {
        PoolKey memory _poolKey = poolKey;

        token0 = Currency.unwrap(_poolKey.currency0);
        token1 = Currency.unwrap(_poolKey.currency1);
    }

    function _checkTokens(
        PoolKey memory poolKey_,
        address token0_,
        address token1_,
        bool isInversed_
    ) internal pure {
        if (isInversed_) {
            if (token0_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency1) != address(0))
                {
                    revert Currency0DtToken0(
                        Currency.unwrap(poolKey_.currency1), token0_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency1) != token0_)
            {
                revert Currency0DtToken0(
                    Currency.unwrap(poolKey_.currency1), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert Currency1DtToken1(
                        Currency.unwrap(poolKey_.currency0), token1_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token1_)
            {
                revert Currency1DtToken1(
                    Currency.unwrap(poolKey_.currency0), token1_
                );
            }
        } else {
            if (token0_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert Currency0DtToken0(
                        Currency.unwrap(poolKey_.currency0), token0_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token0_)
            {
                revert Currency0DtToken0(
                    Currency.unwrap(poolKey_.currency0), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency1) != address(0))
                {
                    revert Currency1DtToken1(
                        Currency.unwrap(poolKey_.currency1), token1_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency1) != token1_)
            {
                revert Currency1DtToken1(
                    Currency.unwrap(poolKey_.currency1), token1_
                );
            }
        }
    }

    // #region view functions.

    // #endregion internal functions.
}
