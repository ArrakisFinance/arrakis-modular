// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {
    PIPS,
    BASE,
    NATIVE_COIN,
    TEN_PERCENT
} from "../constants/CArrakis.sol";
import {
    UnderlyingPayload,
    Range as PoolRange,
    Withdraw,
    SwapPayload,
    SwapBalances
} from "../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

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
abstract contract UniV4StandardModule is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
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

    // #endregion immutable properties

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    // #region public properties.

    IArrakisMetaVault public metaVault;
    IERC20Metadata public token0;
    IERC20Metadata public token1;
    bool public isInversed;
    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint256 public managerFeePIPS;
    IOracleWrapper public oracle;
    uint24 public maxSlippage;

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

    constructor(address poolManager_, address guardian_) {
        // #region checks.
        if (poolManager_ == address(0)) revert AddressZero();
        if (guardian_ == address(0)) revert AddressZero();
        // #endregion checks.

        poolManager = IPoolManager(poolManager_);

        _guardian = guardian_;

        _disableInitializers();
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

    function initialize(
        uint256 init0_,
        uint256 init1_,
        bool isInversed_,
        PoolKey calldata poolKey_,
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address metaVault_
    ) external initializer {
        // #region checks.
        if (
            metaVault_ == address(0) || address(oracle_) == address(0)
        ) revert AddressZero();
        if (maxSlippage_ > TEN_PERCENT) {
            revert MaxSlippageGtTenPercent();
        }

        // #endregion checks.

        metaVault = IArrakisMetaVault(metaVault_);
        isInversed = isInversed_;
        oracle = oracle_;
        maxSlippage = maxSlippage_;

        address _token0 = IArrakisMetaVault(metaVault_).token0();
        address _token1 = IArrakisMetaVault(metaVault_).token1();

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);

        if (isInversed_) {
            _init1 = init0_;
            _init0 = init1_;
        } else {
            _init0 = init0_;
            _init1 = init1_;
        }

        // #region poolKey initialization.

        _checkTokens(poolKey_, _token0, _token1, isInversed_);
        _checkPermissions(poolKey_);

        /// @dev check if the pool is initialized.
        PoolId poolId = poolKey_.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        poolKey = poolKey_;

        // #endregion poolKey initialization.

        __ReentrancyGuard_init();
        __Pausable_init();
    }

    function initializePosition(bytes calldata) external {
        /// @dev put tokens into poolManager

        bytes memory data = abi.encode(3);

        poolManager.unlock(data);
    }

    // #region only manager functions.

    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_,
        SwapPayload calldata swapPayload_
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
        // no swap happens here.
        SwapPayload memory swapPayload;

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

        _internalRebalance(liquidityRanges, swapPayload);

        // #endregion get liquidities and remove.

        // #endregion remove any remaining liquidity on the previous pool.

        // #region set PoolKey.

        poolKey = poolKey_;

        // #endregion set PoolKey.

        // #region add liquidity on the new pool.

        if (liquidityRanges_.length > 0) {
            _internalRebalance(liquidityRanges_, swapPayload_);
        }

        // #endregion add liquidity on the new pool.

        emit LogSetPool(poolKey, poolKey = poolKey_);
    }

    // #endregion only manager functions.

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

    function rebalance(
        LiquidityRange[] memory liquidityRanges_,
        SwapPayload memory swapPayload_
    )
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
        _internalRebalance(liquidityRanges_, swapPayload_);
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
    function setManagerFeePIPS(
        uint256 newFeePIPS_
    ) external onlyManager {
        uint256 _managerFeePIPS = managerFeePIPS;
        if (_managerFeePIPS == newFeePIPS_) revert SameManagerFee();
        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);
        managerFeePIPS = newFeePIPS_;
        emit LogSetManagerFeePIPS(_managerFeePIPS, newFeePIPS_);
    }

    // in case of we swith module and get some ether from it.
    receive() external payable {}

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
        PoolKey memory _poolKey = poolKey;

        (address _token0, address _token1) = _getTokens(_poolKey);

        uint256 fees0;
        uint256 fees1;

        (amount0, amount1, fees0, fees1) = UnderlyingV4
            .totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            })
        );

        amount0 =
            amount0 - FullMath.mulDiv(fees0, managerFeePIPS, PIPS);
        amount1 =
            amount1 - FullMath.mulDiv(fees1, managerFeePIPS, PIPS);

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        uint256 length = _ranges.length;
        PoolKey memory _poolKey = poolKey;
        PoolRange[] memory poolRanges = new PoolRange[](length);

        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            poolRanges[i] = PoolRange({
                lowerTick: range.tickLower,
                upperTick: range.tickUpper,
                poolKey: poolKey
            });
        }

        (address _token0, address _token1) = _getTokens(_poolKey);

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
        PoolKey memory _poolKey = poolKey;
        (address _token0, address _token1) = _getTokens(_poolKey);

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

    function _unlockCallback(
         IPoolManager _poolManager,
         uint256 action,
         bytes memory data
    ) internal returns (bytes memory) {
        if (action == 1) {
            (address receiver, uint256 proportion) =
                abi.decode(data, (address, uint256));
            return _withdraw(
                Withdraw({
                    poolManager: _poolManager,
                    receiver: receiver,
                    proportion: proportion
                })
            );
        }
        if (action == 2) {
            (
                LiquidityRange[] memory liquidityRanges,
                SwapPayload memory swapPayload
            ) = abi.decode(data, (LiquidityRange[], SwapPayload));
            return
                _rebalance(_poolManager, liquidityRanges, swapPayload);
        }
        /// @dev initialize position.
        if (action == 3) {
            return _initializePosition(_poolManager);
        }

        revert CallBackNotSupported();
    }

    function _withdraw(
        Withdraw memory withdraw_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        PoolId poolId = _poolKey.toId();
        uint256 length = _ranges.length;

        // #region fees computations.

        uint256 fee0;
        uint256 fee1;
        {
            PoolRange[] memory poolRanges = _getPoolRanges(length);

            (address _token0, address _token1) = _getTokens(_poolKey);

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: withdraw_.poolManager,
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

            Position.State memory state;
            (
                state.liquidity,
                state.feeGrowthInside0LastX128,
                state.feeGrowthInside1LastX128
            ) = withdraw_.poolManager.getPositionInfo(
                poolId,
                address(this),
                range.tickLower,
                range.tickUpper,
                ""
            );

            /// @dev multiply -1 because we will remove liquidity.
            uint256 liquidity = FullMath.mulDiv(
                uint256(state.liquidity), withdraw_.proportion, BASE
            );

            if (liquidity == uint256(state.liquidity)) {
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
                withdraw_.poolManager.modifyLiquidity(
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
                FullMath.mulDiv(leftOver0, withdraw_.proportion, BASE);
            uint256 leftOver1ToBurn =
                FullMath.mulDiv(leftOver1, withdraw_.proportion, BASE);

            if (leftOver0ToBurn > 0) {
                withdraw_.poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency0),
                    leftOver0ToBurn
                );
            }
            if (leftOver1ToBurn > 0) {
                withdraw_.poolManager.burn(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency1),
                    leftOver1ToBurn
                );
            }
        }

        // #endregion get how much left over we have on poolManager and mint.

        uint256 amount0 = SafeCast.toUint256(
            withdraw_.poolManager.currencyDelta(
                address(this), _poolKey.currency0
            )
        );

        uint256 amount1 = SafeCast.toUint256(
            withdraw_.poolManager.currencyDelta(
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
                    fee0 - managerFee0, withdraw_.proportion, BASE
                );
                fee1ToWithdraw = FullMath.mulDiv(
                    fee1 - managerFee1, withdraw_.proportion, BASE
                );

                // #endregion manager fees.

                withdraw_.poolManager.take(
                    _poolKey.currency0, manager, managerFee0
                );
                withdraw_.poolManager.take(
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

            withdraw_.poolManager.take(
                _poolKey.currency0, withdraw_.receiver, amount0
            );
            withdraw_.poolManager.take(
                _poolKey.currency1, withdraw_.receiver, amount1
            );
        }

        // #endregion take and send token to receiver.

        result = isInversed
            ? abi.encode(amount1, amount0)
            : abi.encode(amount0, amount1);

        // #region mint extra collected fees.

        {
            (amount0, amount1) = _checkCurrencyBalances();

            withdraw_.poolManager.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency0),
                amount0
            );
            withdraw_.poolManager.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency1),
                amount1
            );
        }

        // #endregion mint extra collected fees.
    }

    function _internalRebalance(
        LiquidityRange[] memory liquidityRanges_,
        SwapPayload memory swapPayload_
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
            abi.encode(2, abi.encode(liquidityRanges_, swapPayload_));

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

    function _rebalance(
        IPoolManager poolManager_,
        LiquidityRange[] memory liquidityRanges_,
        SwapPayload memory swapPayload_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        uint256 length = liquidityRanges_.length;
        // #region fees computations.

        uint256 fee0;
        uint256 fee1;
        {
            PoolRange[] memory poolRanges =
                _getPoolRanges(_ranges.length);

            (address _token0, address _token1) = _getTokens(_poolKey);

            (,, fee0, fee1) = UnderlyingV4.totalUnderlyingWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager_,
                    token0: _token0,
                    token1: _token1,
                    self: address(this)
                })
            );
        }

        // #endregion fees computations.

        {
            // #region add liquidities.

            uint256 amount0Minted;
            uint256 amount1Minted;
            uint256 amount0Burned;
            uint256 amount1Burned;

            PoolId poolId = _poolKey.toId();

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
            {
                uint256 managerFee0;
                uint256 managerFee1;
                address manager = metaVault.manager();

                managerFee0 =
                    FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
                managerFee1 =
                    FullMath.mulDiv(fee1, managerFeePIPS, PIPS);

                if (managerFee0 > 0) {
                    poolManager_.take(
                        _poolKey.currency0, manager, managerFee0
                    );
                }
                if (managerFee1 > 0) {
                    poolManager_.take(
                        _poolKey.currency1, manager, managerFee1
                    );
                }

                if (managerFee0 > 0 || managerFee1 > 0) {
                    emit LogWithdrawManagerBalance(
                        manager, managerFee0, managerFee1
                    );
                }

                result = isInversed
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
        }

        // #region swap.

        if (swapPayload_.amountIn > 0) {
            IERC20Metadata _token0 = token0;
            IERC20Metadata _token1 = token1;

            _checkMinReturn(
                swapPayload_.zeroForOne,
                swapPayload_.expectedMinReturn,
                swapPayload_.amountIn,
                _token0.decimals(),
                _token1.decimals()
            );

            SwapBalances memory balances;
            {
                balances.initBalance0 =
                    _token0.balanceOf(address(this));
                balances.initBalance1 =
                    _token1.balanceOf(address(this));

                if (swapPayload_.zeroForOne) {
                    poolManager_.take(
                        address(token0) == NATIVE_COIN
                            ? Currency.wrap(address(0))
                            : Currency.wrap(address(token0)),
                        address(this),
                        swapPayload_.amountIn
                    );

                    balances.actual0 = _token0.balanceOf(
                        address(this)
                    ) - balances.initBalance0;
                } else {
                    poolManager_.take(
                        address(token1) == NATIVE_COIN
                            ? Currency.wrap(address(0))
                            : Currency.wrap(address(token1)),
                        address(this),
                        swapPayload_.amountIn
                    );

                    balances.actual1 = _token1.balanceOf(
                        address(this)
                    ) - balances.initBalance1;
                }

                if (swapPayload_.zeroForOne) {
                    _token0.forceApprove(
                        swapPayload_.router, swapPayload_.amountIn
                    );
                } else {
                    _token1.forceApprove(
                        swapPayload_.router, swapPayload_.amountIn
                    );
                }

                if (swapPayload_.router == address(metaVault)) {
                    revert WrongRouter();
                }

                {
                    (bool success,) =
                        swapPayload_.router.call(swapPayload_.payload);
                    if (!success) revert SwapCallFailed();
                }

                if (swapPayload_.zeroForOne) {
                    _token0.forceApprove(swapPayload_.router, 0);
                } else {
                    _token1.forceApprove(swapPayload_.router, 0);
                }

                balances.balance0 = _token0.balanceOf(address(this))
                    - balances.initBalance0;
                balances.balance1 = _token1.balanceOf(address(this))
                    - balances.initBalance1;

                if (swapPayload_.zeroForOne) {
                    if (
                        balances.actual1
                            + swapPayload_.expectedMinReturn
                            > balances.balance1
                    ) {
                        revert SlippageTooHigh();
                    }
                } else {
                    if (
                        balances.actual0
                            + swapPayload_.expectedMinReturn
                            > balances.balance0
                    ) {
                        revert SlippageTooHigh();
                    }
                }

                {
                    if (balances.balance0 > 0) {
                        if (address(token0) == NATIVE_COIN) {
                            poolManager_.sync(
                                Currency.wrap(address(0))
                            );
                            poolManager_.settle{
                                value: balances.balance0
                            }();
                        } else {
                            poolManager_.sync(
                                Currency.wrap(address(token0))
                            );
                            _token0.safeTransfer(
                                address(poolManager),
                                balances.balance0
                            );
                            poolManager_.settle();
                        }
                    }
                    if (balances.balance1 > 0) {
                        if (address(token1) == NATIVE_COIN) {
                            poolManager_.sync(
                                Currency.wrap(address(0))
                            );
                            poolManager_.settle{
                                value: balances.balance1
                            }();
                        } else {
                            poolManager_.sync(
                                Currency.wrap(address(token1))
                            );
                            _token1.safeTransfer(
                                address(poolManager),
                                balances.balance1
                            );
                            poolManager_.settle();
                        }
                    }
                }
            }
        }

        // #endregion swap.

        {
            // #region get how much left over we have on poolManager and mint.

            int256 amt0 = poolManager_.currencyDelta(
                address(this), poolKey.currency0
            );

            int256 amt1 = poolManager_.currencyDelta(
                address(this), poolKey.currency1
            );

            if (amt0 > 0) {
                poolManager_.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency0),
                    SafeCast.toUint256(amt0)
                );
            } else if (amt0 < 0) {
                poolManager_.burn(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency0),
                    SafeCast.toUint256(-amt0)
                );
            }
            if (amt1 > 0) {
                poolManager_.mint(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency1),
                    SafeCast.toUint256(amt1)
                );
            } else if (amt1 < 0) {
                poolManager_.burn(
                    address(this),
                    CurrencyLibrary.toId(poolKey.currency1),
                    SafeCast.toUint256(-amt1)
                );
            }

            // #endregion get how much left over we have on poolManager and mint.
        }

        // #endregion collect and sent fees to manager.
    }

    function _initializePosition(
        IPoolManager poolManager_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;
        // #region get current balances.

        uint256 amount0 = _poolKey.currency0.isAddressZero()
            ? address(this).balance
            : token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));

        // #endregion get current balances.

        // #region mint into poolManager.

        if (amount0 > 0) {
            // Mint
            poolManager_.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency0),
                amount0
            );

            // Sync and settle
            poolManager_.sync(_poolKey.currency0);
            if (_poolKey.currency0.isAddressZero()) {
                /// @dev no need to use Address lib for PoolManager.
                poolManager_.settle{value: amount0}();
            } else {
                token0.safeTransfer(address(poolManager_), amount0);
                poolManager_.settle();
            }
        }
        if (amount1 > 0) {
            // Mint
            poolManager_.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency1),
                amount1
            );
            poolManager_.sync(_poolKey.currency1);
            token1.safeTransfer(address(poolManager_), amount1);
            poolManager_.settle();
        }

        // #endregion mint into poolManager.

        return isInversed
            ? abi.encode(amount1, amount0)
            : abi.encode(amount0, amount1);
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
        // #region get liqudity.

        Position.State memory state;
        (
            state.liquidity,
            state.feeGrowthInside0LastX128,
            state.feeGrowthInside1LastX128
        ) = poolManager.getPositionInfo(
            poolId_, address(this), tickLower_, tickUpper_, ""
        );

        // #endregion get liquidity.

        // #region effects.

        bytes32 positionId =
            keccak256(abi.encode(poolId_, tickLower_, tickUpper_));

        if (!_activeRanges[positionId]) {
            revert RangeShouldBeActive(tickLower_, tickUpper_);
        }

        if (liquidityToRemove_ > state.liquidity) {
            revert OverBurning();
        }

        if (liquidityToRemove_ == state.liquidity) {
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
    }

    function _getPoolRanges(
        uint256 length_
    ) internal view returns (PoolRange[] memory poolRanges) {
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

    function _getTokens(
        PoolKey memory poolKey_
    ) internal view returns (address token0, address token1) {
        token0 = Currency.unwrap(poolKey_.currency0);
        token1 = Currency.unwrap(poolKey_.currency1);
    }

    function _checkTokens(
        PoolKey memory poolKey_,
        address token0_,
        address token1_,
        bool isInversed_
    ) internal pure {
        if (isInversed_) {
            /// @dev Currency.unwrap(poolKey_.currency1) != address(0) is not possible
            /// @dev because currency0 should be lower currency1.

            if (token0_ == NATIVE_COIN) {
                revert NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token0_)
            {
                revert Currency1DtToken0(
                    Currency.unwrap(poolKey_.currency1), token0_
                );
            }

            if (token1_ == NATIVE_COIN) {
                if (Currency.unwrap(poolKey_.currency0) != address(0))
                {
                    revert Currency0DtToken1(
                        Currency.unwrap(poolKey_.currency0), token1_
                    );
                }
            } else if (Currency.unwrap(poolKey_.currency0) != token1_)
            {
                revert Currency0DtToken1(
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
                revert NativeCoinCannotBeToken1();
            } else if (Currency.unwrap(poolKey_.currency1) != token1_)
            {
                revert Currency1DtToken1(
                    Currency.unwrap(poolKey_.currency1), token1_
                );
            }
        }
    }

    function _checkPermissions(
        PoolKey memory poolKey_
    ) internal virtual {
        if (
            poolKey_.hooks.hasPermission(
                Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
            )
                || poolKey_.hooks.hasPermission(
                    Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
                )
        ) revert NoModifyLiquidityHooks();
    }

    function _checkMinReturn(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        uint8 decimals0_,
        uint8 decimals1_
    ) internal view {
        if (zeroForOne_) {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_, 10 ** decimals0_, amountIn_
                )
                    < FullMath.mulDiv(
                        oracle.getPrice0(), PIPS - maxSlippage, PIPS
                    )
            ) revert ExpectedMinReturnTooLow();
        } else {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_, 10 ** decimals1_, amountIn_
                )
                    < FullMath.mulDiv(
                        oracle.getPrice1(), PIPS - maxSlippage, PIPS
                    )
            ) revert ExpectedMinReturnTooLow();
        }
    }

    // #region view functions.

    // #endregion internal functions.
}
