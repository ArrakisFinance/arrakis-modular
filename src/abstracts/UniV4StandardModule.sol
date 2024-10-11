// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {
    PIPS,
    BASE,
    NATIVE_COIN,
    TEN_PERCENT,
    NATIVE_COIN_DECIMALS
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
import {
    BalanceDelta,
    BalanceDeltaLibrary,
    toBalanceDelta
} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

/// @notice this module can only set uni v4 pool that have generic hook,
/// that don't require specific action to become liquidity provider.
/// @dev due to native coin standard difference between uni V4 and arrakis,
/// we are assuming that all inputed amounts are using arrakis vault token0/token1
/// as reference. Internal logic of UniV4StandardModule will handle the conversion or
/// use the poolKey to interact with the poolManager.
abstract contract UniV4StandardModule is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IArrakisLPModule,
    IArrakisLPModuleID,
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
    using BalanceDeltaLibrary for BalanceDelta;

    // #region enum.

    enum Action {
        WITHDRAW,
        REBALANCE,
        INITIALIZE_POSITION,
        DEPOSIT_FUND
    }

    // #endregion enum.

    // #region immutable properties.

    /// @notice function used to get the uniswap v4 pool manager.
    IPoolManager public immutable poolManager;

    // #endregion immutable properties.

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    // #region public properties.

    /// @notice module's metaVault as IArrakisMetaVault.
    IArrakisMetaVault public metaVault;
    /// @notice module's token0 as IERC20Metadata.
    IERC20Metadata public token0;
    /// @notice module's token1 as IERC20Metadata.
    IERC20Metadata public token1;
    /// @notice boolean to know if the poolKey's currencies pair are inversed.
    bool public isInversed;
    /// @notice manager fees share.
    uint256 public managerFeePIPS;
    /// oracle that will be used to proctect rebalances against attacks.
    IOracleWrapper public oracle;
    /// @notice max slippage that can occur during swap rebalance.
    uint24 public maxSlippage;
    /// @notice pool's key of the module.
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

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the uniswap v4 standard module.
    /// @dev this function will deposit fund as left over on poolManager.
    /// @param init0_ initial amount of token0 to provide to uniswap standard module.
    /// @param init1_ initial amount of token1 to provide to valantis module.
    /// @param isInversed_ boolean to check if the poolKey's currencies pair are inversed,
    /// compared to the module's tokens pair.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param oracle_ address of the oracle used by the uniswap v4 standard module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param metaVault_ address of the meta vault
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

    /// @notice function used to initialize the module
    /// when a module switch happen
    function initializePosition(
        bytes calldata
    ) external onlyMetaVault {
        /// @dev put tokens into poolManager
        bytes memory data =
            abi.encode(Action.INITIALIZE_POSITION, bytes(""));

        bytes memory result = poolManager.unlock(data);
    }

    // #region only manager functions.

    /// @notice function used to set the pool for the module.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param liquidityRanges_ list of liquidity ranges to be used by the module on the new pool.
    /// @param swapPayload_ swap payload to be used during rebalance.
    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_,
        SwapPayload calldata swapPayload_
    ) external onlyManager nonReentrant {
        address _token0 = address(token0);
        address _token1 = address(token1);
        PoolKey memory _poolKey = poolKey;

        _checkTokens(poolKey_, _token0, _token1, isInversed);
        _checkPermissions(poolKey_);

        if (
            poolKey_.fee == _poolKey.fee
                && poolKey_.tickSpacing == _poolKey.tickSpacing
                && address(poolKey_.hooks) == address(_poolKey.hooks)
        ) revert SamePool();

        /// @dev check if the pool is initialized.
        PoolId poolId = poolKey_.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        // #region remove any remaining liquidity on the previous pool.

        // #region get liquidities and remove.

        uint256 length = _ranges.length;

        PoolId currentPoolId = _poolKey.toId();
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
                    bytes32(0)
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

        {
            // no swap happens here.
            SwapPayload memory swapPayload;
            _internalRebalance(liquidityRanges, swapPayload);
        }

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

        emit LogSetPool(_poolKey, poolKey_);
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

        bytes memory data = abi.encode(
            Action.WITHDRAW, abi.encode(receiver_, proportion_)
        );

        bytes memory result = poolManager.unlock(data);

        (amount0, amount1) = abi.decode(result, (uint256, uint256));

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    /// @notice function used to rebalance the inventory of the module.
    /// @param liquidityRanges_ list of liquidity ranges to be used by the module.
    /// @param swapPayload_ swap payload to be used during rebalance.
    /// @return amount0Minted amount of token0 minted.
    /// @return amount1Minted amount of token1 minted.
    /// @return amount0Burned amount of token0 burned.
    /// @return amount1Burned amount of token1 burned.
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

        /// @dev default swapPayload, no swap happens here.
        /// swapPayload will be empty. And will use it to do rebalance and collect fees.
        SwapPayload memory swapPayload;

        bytes memory data = abi.encode(
            Action.REBALANCE, abi.encode(liquidityRanges, swapPayload)
        );

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
            ? NATIVE_COIN_DECIMALS
            : IERC20Metadata(_token0).decimals();
        uint8 token1Decimals = _token1 == address(0)
            ? NATIVE_COIN_DECIMALS
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

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return managerFee0 amount of token0 that manager earned.
    function managerBalance0()
        external
        view
        returns (uint256 managerFee0)
    {
        PoolRange[] memory poolRanges = _getPoolRanges(_ranges.length);

        (address _token0, address _token1) = _getTokens(poolKey);

        (,, uint256 fee0,) = UnderlyingV4.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            })
        );

        managerFee0 = FullMath.mulDiv(fee0, managerFeePIPS, PIPS);
    }

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return managerFee1 amount of token1 that manager earned.
    function managerBalance1()
        external
        view
        returns (uint256 managerFee1)
    {
        PoolRange[] memory poolRanges = _getPoolRanges(_ranges.length);

        (address _token0, address _token1) = _getTokens(poolKey);

        (,,, uint256 fee1) = UnderlyingV4.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            })
        );

        managerFee1 = FullMath.mulDiv(fee1, managerFeePIPS, PIPS);
    }

    // #endregion view functions.

    // #region internal functions.

    function _unlockCallback(
        IPoolManager _poolManager,
        Action action,
        bytes memory data
    ) internal returns (bytes memory) {
        if (action == Action.WITHDRAW) {
            (address receiver, uint256 proportion) =
                abi.decode(data, (address, uint256));
            return _withdraw(
                Withdraw({
                    poolManager: _poolManager,
                    receiver: receiver,
                    proportion: proportion,
                    amount0: 0,
                    amount1: 0,
                    fee0: 0,
                    fee1: 0
                })
            );
        }
        if (action == Action.REBALANCE) {
            (
                LiquidityRange[] memory liquidityRanges,
                SwapPayload memory swapPayload
            ) = abi.decode(data, (LiquidityRange[], SwapPayload));
            return
                _rebalance(_poolManager, liquidityRanges, swapPayload);
        }
        /// @dev initialize position.
        if (action == Action.INITIALIZE_POSITION) {
            return _initializePosition(_poolManager);
        }
    }

    function _withdraw(
        Withdraw memory withdraw_
    ) internal returns (bytes memory result) {
        PoolKey memory _poolKey = poolKey;

        // #region get liquidity for each positions and burn.

        {
            BalanceDelta delta;
            {
                BalanceDelta fees;
                PoolId poolId = _poolKey.toId();
                uint256 length = _ranges.length;

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
                        bytes32(0)
                    );

                    /// @dev multiply -1 because we will remove liquidity.
                    uint256 liquidity = FullMath.mulDiv(
                        uint256(state.liquidity),
                        withdraw_.proportion,
                        BASE
                    );

                    if (liquidity == uint256(state.liquidity)) {
                        bytes32 positionId = keccak256(
                            abi.encode(
                                poolId,
                                range.tickLower,
                                range.tickUpper
                            )
                        );
                        _activeRanges[positionId] = false;
                        (uint256 indexToRemove, uint256 l) =
                        _getRangeIndex(
                            range.tickLower, range.tickUpper
                        );

                        _ranges[indexToRemove] = _ranges[l - 1];
                        _ranges.pop();
                    }

                    if (liquidity > 0) {
                        (
                            BalanceDelta callerDelta,
                            BalanceDelta feesAccrued
                        ) = withdraw_.poolManager.modifyLiquidity(
                            _poolKey,
                            IPoolManager.ModifyLiquidityParams({
                                liquidityDelta: -1
                                    * SafeCast.toInt256(liquidity),
                                tickLower: range.tickLower,
                                tickUpper: range.tickUpper,
                                salt: bytes32(0)
                            }),
                            ""
                        );

                        delta = delta + callerDelta;
                        fees = fees + feesAccrued;
                    }
                }
                withdraw_.fee0 =
                    SafeCast.toUint256(int256(fees.amount0()));
                withdraw_.fee1 =
                    SafeCast.toUint256(int256(fees.amount1()));
            }

            // #endregion get liquidity for each positions and burn.

            // #region get how much left over we have on poolManager and burn.

            {
                (, uint256 leftOver0,, uint256 leftOver1) =
                    _get6909Balances();

                // rounding up during mint only
                uint256 leftOver0ToBurn = FullMath.mulDiv(
                    leftOver0, withdraw_.proportion, BASE
                );
                uint256 leftOver1ToBurn = FullMath.mulDiv(
                    leftOver1, withdraw_.proportion, BASE
                );

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

                delta = delta
                    + toBalanceDelta(
                        SafeCast.toInt128(
                            SafeCast.toInt256(leftOver0ToBurn)
                        ),
                        SafeCast.toInt128(
                            SafeCast.toInt256(leftOver1ToBurn)
                        )
                    );

                withdraw_.amount0 =
                    SafeCast.toUint256(int256(delta.amount0()));
                withdraw_.amount1 =
                    SafeCast.toUint256(int256(delta.amount1()));
            }
        }
        // #endregion get how much left over we have on poolManager and mint.

        // #region take and send token to receiver.

        /// @dev if receiver is a smart contract, the sm should implement receive
        /// fallback function.
        {
            {
                uint256 managerFee0 = FullMath.mulDiv(
                    withdraw_.fee0, managerFeePIPS, PIPS
                );
                uint256 managerFee1 = FullMath.mulDiv(
                    withdraw_.fee1, managerFeePIPS, PIPS
                );

                {
                    uint256 amount0ToTake;
                    uint256 amount1ToTake;

                    /// @dev if proportion is 100% we take all fees, to prevent
                    /// rounding errors.
                    if (withdraw_.proportion == BASE) {
                        amount0ToTake =
                            withdraw_.amount0 - managerFee0;
                        amount1ToTake =
                            withdraw_.amount1 - managerFee1;
                    } else {
                        amount0ToTake = withdraw_.amount0
                            - withdraw_.fee0
                            + FullMath.mulDiv(
                                withdraw_.fee0 - managerFee0,
                                withdraw_.proportion,
                                BASE
                            );
                        amount1ToTake = withdraw_.amount1
                            - withdraw_.fee1
                            + FullMath.mulDiv(
                                withdraw_.fee1 - managerFee1,
                                withdraw_.proportion,
                                BASE
                            );
                    }

                    if (amount0ToTake > 0) {
                        withdraw_.poolManager.take(
                            _poolKey.currency0,
                            withdraw_.receiver,
                            amount0ToTake
                        );

                        withdraw_.amount0 -= amount0ToTake;
                    }

                    if (amount1ToTake > 0) {
                        withdraw_.poolManager.take(
                            _poolKey.currency1,
                            withdraw_.receiver,
                            amount1ToTake
                        );
                        withdraw_.amount1 -= amount1ToTake;
                    }

                    result = isInversed
                        ? abi.encode(amount1ToTake, amount0ToTake)
                        : abi.encode(amount0ToTake, amount1ToTake);
                }

                // #region manager fees.

                address manager;
                if (managerFee0 > 0 || managerFee1 > 0) {
                    manager = metaVault.manager();

                    emit LogWithdrawManagerBalance(
                        manager, managerFee0, managerFee1
                    );
                }

                if (managerFee0 > 0) {
                    withdraw_.poolManager.take(
                        _poolKey.currency0, manager, managerFee0
                    );

                    withdraw_.amount0 -= managerFee0;
                }
                if (managerFee1 > 0) {
                    withdraw_.poolManager.take(
                        _poolKey.currency1, manager, managerFee1
                    );

                    withdraw_.amount1 -= managerFee1;
                }

                // #endregion manager fees.
            }
        }

        // #endregion take and send token to receiver.

        // #region mint extra collected fees.

        {
            if (withdraw_.amount0 > 0) {
                withdraw_.poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency0),
                    withdraw_.amount0
                );
            }
            if (withdraw_.amount1 > 0) {
                withdraw_.poolManager.mint(
                    address(this),
                    CurrencyLibrary.toId(_poolKey.currency1),
                    withdraw_.amount1
                );
            }
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
        bytes memory data = abi.encode(
            Action.REBALANCE,
            abi.encode(liquidityRanges_, swapPayload_)
        );

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

        /// @dev here we are reasonning in term of token0 and token1 of vault (not poolKey).
        if (swapPayload_.amountIn > 0) {
            IERC20Metadata _token0 = token0;
            IERC20Metadata _token1 = token1;

            bool isToken0Native = address(_token0) == NATIVE_COIN;
            bool isToken1Native = address(_token1) == NATIVE_COIN;

            _checkMinReturn(
                swapPayload_.zeroForOne,
                swapPayload_.expectedMinReturn,
                swapPayload_.amountIn,
                isToken0Native
                    ? NATIVE_COIN_DECIMALS
                    : _token0.decimals(),
                isToken1Native
                    ? NATIVE_COIN_DECIMALS
                    : _token1.decimals()
            );

            SwapBalances memory balances;
            {
                balances.initBalance0 = isToken0Native
                    ? address(this).balance
                    : _token0.balanceOf(address(this));
                balances.initBalance1 = isToken1Native
                    ? address(this).balance
                    : _token1.balanceOf(address(this));

                uint256 ethToSend;

                if (swapPayload_.zeroForOne) {
                    if (isToken0Native) {
                        poolManager_.take(
                            Currency.wrap(address(0)),
                            address(this),
                            swapPayload_.amountIn
                        );

                        ethToSend = swapPayload_.amountIn;

                        balances.actual0 = address(this).balance
                            - balances.initBalance0;
                    } else {
                        poolManager_.take(
                            Currency.wrap(address(_token0)),
                            address(this),
                            swapPayload_.amountIn
                        );

                        balances.actual0 = _token0.balanceOf(
                            address(this)
                        ) - balances.initBalance0;
                    }
                } else {
                    if (isToken1Native) {
                        poolManager_.take(
                            Currency.wrap(address(0)),
                            address(this),
                            swapPayload_.amountIn
                        );

                        ethToSend = swapPayload_.amountIn;
                        balances.actual1 = address(this).balance
                            - balances.initBalance1;
                    } else {
                        poolManager_.take(
                            Currency.wrap(address(_token1)),
                            address(this),
                            swapPayload_.amountIn
                        );
                        balances.actual1 = _token1.balanceOf(
                            address(this)
                        ) - balances.initBalance1;
                    }
                }

                if (swapPayload_.zeroForOne && !isToken0Native) {
                    _token0.forceApprove(
                        swapPayload_.router, swapPayload_.amountIn
                    );
                } else if (
                    !swapPayload_.zeroForOne && !isToken1Native
                ) {
                    _token1.forceApprove(
                        swapPayload_.router, swapPayload_.amountIn
                    );
                }

                if (swapPayload_.router == address(metaVault)) {
                    revert WrongRouter();
                }

                {
                    payable(swapPayload_.router).functionCallWithValue(
                        swapPayload_.payload, ethToSend
                    );
                }

                if (swapPayload_.zeroForOne && !isToken0Native) {
                    _token0.forceApprove(swapPayload_.router, 0);
                } else if (
                    !swapPayload_.zeroForOne && !isToken1Native
                ) {
                    _token1.forceApprove(swapPayload_.router, 0);
                }

                balances.balance0 = (
                    isToken0Native
                        ? address(this).balance
                        : _token0.balanceOf(address(this))
                ) - balances.initBalance0;
                balances.balance1 = (
                    isToken1Native
                        ? address(this).balance
                        : _token1.balanceOf(address(this))
                ) - balances.initBalance1;

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
                        if (isToken0Native) {
                            poolManager_.sync(
                                Currency.wrap(address(0))
                            );
                            poolManager_.settle{
                                value: balances.balance0
                            }();
                        } else {
                            poolManager_.sync(
                                Currency.wrap(address(_token0))
                            );
                            _token0.safeTransfer(
                                address(poolManager),
                                balances.balance0
                            );
                            poolManager_.settle();
                        }
                    }
                    if (balances.balance1 > 0) {
                        if (isToken1Native) {
                            poolManager_.sync(
                                Currency.wrap(address(0))
                            );
                            poolManager_.settle{
                                value: balances.balance1
                            }();
                        } else {
                            poolManager_.sync(
                                Currency.wrap(address(_token1))
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

        bool isCurrency0Native = _poolKey.currency0.isAddressZero();

        // #region get current balances.
        uint256 amountCurrency0 = isCurrency0Native
            ? address(this).balance
            : IERC20Metadata(Currency.unwrap(_poolKey.currency0))
                .balanceOf(address(this));
        uint256 amountCurrency1 = IERC20Metadata(
            Currency.unwrap(_poolKey.currency1)
        ).balanceOf(address(this));
        // #endregion get current balances.

        // #region mint into poolManager.

        if (amountCurrency0 > 0) {
            // Mint
            poolManager_.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency0),
                amountCurrency0
            );

            // Sync and settle
            poolManager_.sync(_poolKey.currency0);
            if (isCurrency0Native) {
                /// @dev no need to use Address lib for PoolManager.
                poolManager_.settle{value: amountCurrency0}();
            } else {
                IERC20Metadata(Currency.unwrap(_poolKey.currency0))
                    .safeTransfer(address(poolManager_), amountCurrency0);
                poolManager_.settle();
            }
        }
        if (amountCurrency1 > 0) {
            // Mint
            poolManager_.mint(
                address(this),
                CurrencyLibrary.toId(_poolKey.currency1),
                amountCurrency1
            );
            poolManager_.sync(_poolKey.currency1);
            IERC20Metadata(Currency.unwrap(_poolKey.currency1))
                .safeTransfer(address(poolManager_), amountCurrency1);
            poolManager_.settle();
        }

        // #endregion mint into poolManager.

        return isInversed
            ? abi.encode(amountCurrency1, amountCurrency0)
            : abi.encode(amountCurrency0, amountCurrency1);
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

        (BalanceDelta delta,) = poolManager.modifyLiquidity(
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

        (amount0, amount1) = _checkCurrencyDelta(
            int256(delta.amount0()), int256(delta.amount1())
        );

        // #endregion interactions.
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
            poolId_, address(this), tickLower_, tickUpper_, bytes32(0)
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

        (BalanceDelta delta,) = poolManager.modifyLiquidity(
            poolKey_,
            IPoolManager.ModifyLiquidityParams({
                liquidityDelta: -SafeCast.toInt256(uint256(liquidityToRemove_)),
                tickLower: tickLower_,
                tickUpper: tickUpper_,
                salt: bytes32(0)
            }),
            ""
        );

        amount0 = SafeCast.toUint256(delta.amount0());

        amount1 = SafeCast.toUint256(delta.amount1());

        // #endregion interactions.
    }

    // #region view functions.

    function _get6909Balances()
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
        int256 currency1BalanceRaw = poolManager.currencyDelta(
            address(this), poolKey.currency1
        );
        return _checkCurrencyDelta(
            currency0BalanceRaw, currency1BalanceRaw
        );
    }

    function _checkCurrencyDelta(
        int256 currency0BalanceRaw_,
        int256 currency1BalanceRaw_
    ) internal view returns (uint256, uint256) {
        if (currency0BalanceRaw_ > 0) revert InvalidCurrencyDelta();
        uint256 currency0Balance =
            SafeCast.toUint256(-currency0BalanceRaw_);
        if (currency1BalanceRaw_ > 0) revert InvalidCurrencyDelta();
        uint256 currency1Balance =
            SafeCast.toUint256(-currency1BalanceRaw_);

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
            /// @dev Currency.unwrap(poolKey_.currency1) == address(0) is not possible
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
        ) revert NoRemoveLiquidityHooks();
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
