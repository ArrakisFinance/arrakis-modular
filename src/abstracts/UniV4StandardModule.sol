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
import {IOwnable} from "../interfaces/IOwnable.sol";
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
    SwapPayload
} from "../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";
import {UniswapV4} from "../libraries/UniswapV4.sol";
import {IDistributor} from "../interfaces/IDistributor.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {Position} from "@uniswap/v4-core/src/libraries/Position.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IUnlockCallback} from
    "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";

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
    using Address for address payable;
    using StateLibrary for IPoolManager;
    using UniswapV4 for IUniV4StandardModule;

    // #region enum.

    enum Action {
        WITHDRAW,
        REBALANCE,
        DEPOSIT_FUND
    }

    // #endregion enum.

    // #region immutable properties.

    /// @notice function used to get the uniswap v4 pool manager.
    IPoolManager public immutable poolManager;
    IDistributor public immutable distributor;
    address public immutable collector;

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
    /// @notice list of allowed addresses to withdraw eth.
    mapping(address => uint256) public ethWithdrawers;

    // #endregion public properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;

    Range[] internal _ranges;
    mapping(bytes32 => bool) internal _activeRanges;

    // #endregion internal properties.

    // #region storage gaps.

    uint256[37] internal __gap;

    // #endregion storage gaps.

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
        address guardian_,
        address distributor_,
        address collector_
    ) {
        // #region checks.
        if (poolManager_ == address(0)) revert AddressZero();
        if (guardian_ == address(0)) revert AddressZero();
        if (distributor_ == address(0)) revert AddressZero();
        if (collector_ == address(0)) revert AddressZero();
        // #endregion checks.

        poolManager = IPoolManager(poolManager_);

        _guardian = guardian_;
        distributor = IDistributor(distributor_);
        collector = collector_;

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
    /// @param init0_ initial amount of token0 to provide to uniswap standard module.
    /// @param init1_ initial amount of token1 to provide to uniswap standard module.
    /// @param isInversed_ boolean to check if the poolKey's currencies pair are inversed,
    /// compared to the module's tokens pair.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param oracle_ address of the oracle used by the uniswap v4 standard module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param metaVault_ address of the meta vault.
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
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
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

        UniswapV4._checkTokens(
            poolKey_, _token0, _token1, isInversed_
        );
        UniswapV4._checkPermissions(poolKey_);

        /// @dev check if the pool is initialized.
        PoolId poolId = poolKey_.toId();
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        poolKey = poolKey_;

        // #endregion poolKey initialization.

        IDistributor(distributor).toggleOperator(
            address(this), collector
        );

        __ReentrancyGuard_init();
        __Pausable_init();
    }

    /// @notice function used to initialize the module
    /// when a module switch happen
    function initializePosition(
        bytes calldata
    ) external virtual onlyMetaVault {
        /// @dev left over will sit on the module.
    }

    // #region vault owner functions.

    /// @inheritdoc IUniV4StandardModule
    function withdrawEth(
        uint256 amount_
    ) external nonReentrant whenNotPaused {
        if (amount_ == 0) revert AmountZero();
        if (ethWithdrawers[msg.sender] < amount_) {
            revert InsufficientFunds();
        }

        ethWithdrawers[msg.sender] -= amount_;
        payable(msg.sender).sendValue(amount_);

        emit LogWithdrawETH(msg.sender, amount_);
    }

    /// @inheritdoc IUniV4StandardModule
    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external nonReentrant whenNotPaused {
        if (msg.sender != IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }
        uint256 length = tokens_.length;
        if (length != amounts_.length) {
            revert LengthsNotEqual();
        }

        for (uint256 i; i < length; i++) {
            address token = tokens_[i];
            uint256 amount = amounts_[i];

            if (token == address(0)) {
                revert AddressZero();
            }

            if (address(token) != NATIVE_COIN) {
                IERC20Metadata(token).forceApprove(spender_, amount);
            } else {
                ethWithdrawers[spender_] = amount;
            }
        }

        emit LogApproval(spender_, tokens_, amounts_);
    }

    // #endregion vault owner functions.

    // #region only manager functions.

    /// @notice function used to set the pool for the module.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param liquidityRanges_ list of liquidity ranges to be used by the module on the new pool.
    /// @param swapPayload_ swap payload to be used during rebalance.
    /// @param minBurn0_ minimum amount of token0 to burn.
    /// @param minBurn1_ minimum amount of token1 to burn.
    /// @param minDeposit0_ minimum amount of token0 to deposit.
    /// @param minDeposit1_ minimum amount of token1 to deposit.
    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_,
        SwapPayload calldata swapPayload_,
        uint256 minBurn0_,
        uint256 minBurn1_,
        uint256 minDeposit0_,
        uint256 minDeposit1_
    ) external onlyManager nonReentrant whenNotPaused {
        PoolKey memory _poolKey = poolKey;

        UniswapV4._checkTokens(
            poolKey_, address(token0), address(token1), isInversed
        );
        UniswapV4._checkPermissions(poolKey_);

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

        LiquidityRange[] memory liquidityRanges;

        {
            uint256 length = _ranges.length;

            PoolId currentPoolId = _poolKey.toId();
            liquidityRanges = new LiquidityRange[](length);

            for (uint256 i; i < length; i++) {
                Range memory range = _ranges[i];

                uint128 liquidityToRemove = poolManager
                    .getPositionLiquidity(
                    currentPoolId,
                    Position.calculatePositionKey(
                        address(this),
                        range.tickLower,
                        range.tickUpper,
                        bytes32(0)
                    )
                );

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
        }

        {
            // no swap happens here.
            uint256 amount0Burned;
            uint256 amount1Burned;
            {
                SwapPayload memory swapPayload;
                (,, amount0Burned, amount1Burned) =
                    _internalRebalance(liquidityRanges, swapPayload);
            }

            if (minBurn0_ > amount0Burned) revert BurnToken0();
            if (minBurn1_ > amount1Burned) revert BurnToken1();
        }

        // #endregion get liquidities and remove.

        // #endregion remove any remaining liquidity on the previous pool.

        // #region set PoolKey.

        poolKey = poolKey_;

        // #endregion set PoolKey.

        // #region add liquidity on the new pool.

        if (liquidityRanges_.length > 0) {
            (uint256 amount0Minted, uint256 amount1Minted,,) =
                _internalRebalance(liquidityRanges_, swapPayload_);

            if (minDeposit0_ > amount0Minted) revert MintToken0();
            if (minDeposit1_ > amount1Minted) revert MintToken1();
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
        public
        virtual
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
    /// @param swapPayload_ swap payload to be used during rebalance..
    /// @param minBurn0_ minimum amount of token0 to burn.
    /// @param minBurn1_ minimum amount of token1 to burn.
    /// @param minDeposit0_ minimum amount of token0 to deposit.
    /// @param minDeposit1_ minimum amount of token1 to deposit.
    /// @return amount0Minted amount of token0 minted.
    /// @return amount1Minted amount of token1 minted.
    /// @return amount0Burned amount of token0 burned.
    /// @return amount1Burned amount of token1 burned.
    function rebalance(
        LiquidityRange[] memory liquidityRanges_,
        SwapPayload memory swapPayload_,
        uint256 minBurn0_,
        uint256 minBurn1_,
        uint256 minDeposit0_,
        uint256 minDeposit1_
    )
        public
        onlyManager
        nonReentrant
        whenNotPaused
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        )
    {
        (amount0Minted, amount1Minted, amount0Burned, amount1Burned) =
            _internalRebalance(liquidityRanges_, swapPayload_);

        if (minDeposit0_ > amount0Minted) revert MintToken0();
        if (minDeposit1_ > amount1Minted) revert MintToken1();
        if (minBurn0_ > amount0Burned) revert BurnToken0();
        if (minBurn1_ > amount1Burned) revert BurnToken1();
    }

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        public
        nonReentrant
        whenNotPaused
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
    ) external onlyManager whenNotPaused {
        uint256 _managerFeePIPS = managerFeePIPS;
        if (_managerFeePIPS == newFeePIPS_) revert SameManagerFee();
        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        withdrawManagerBalance();

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
        PoolKey memory _poolKey = poolKey;
        PoolRange[] memory poolRanges =
            UniswapV4._getPoolRanges(_ranges, _poolKey);

        uint256 fees0;
        uint256 fees1;

        {
            (uint256 leftOver0, uint256 leftOver1) =
                IUniV4StandardModule(this)._getLeftOvers(_poolKey);

            (uint160 sqrtPriceX96_,,,) =
                poolManager.getSlot0(PoolIdLibrary.toId(_poolKey));

            (amount0, amount1, fees0, fees1) = UnderlyingV4
                .totalUnderlyingAtPriceWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager,
                    self: address(this),
                    leftOver0: leftOver0,
                    leftOver1: leftOver1
                }),
                sqrtPriceX96_
            );
        }

        amount0 = amount0
            - FullMath.mulDivRoundingUp(fees0, managerFeePIPS, PIPS);
        amount1 = amount1
            - FullMath.mulDivRoundingUp(fees1, managerFeePIPS, PIPS);

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
        PoolKey memory _poolKey = poolKey;

        PoolRange[] memory poolRanges =
            UniswapV4._getPoolRanges(_ranges, _poolKey);

        uint256 fees0;
        uint256 fees1;
        {
            (uint256 leftOver0, uint256 leftOver1) =
                IUniV4StandardModule(this)._getLeftOvers(_poolKey);

            (amount0, amount1, fees0, fees1) = UnderlyingV4
                .totalUnderlyingAtPriceWithFees(
                UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: poolManager,
                    self: address(this),
                    leftOver0: leftOver0,
                    leftOver1: leftOver1
                }),
                priceX96_
            );
        }

        amount0 = amount0
            - FullMath.mulDivRoundingUp(fees0, managerFeePIPS, PIPS);
        amount1 = amount1
            - FullMath.mulDivRoundingUp(fees1, managerFeePIPS, PIPS);

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
        (address _token0, address _token1) =
            IUniV4StandardModule(this)._getTokens(_poolKey);

        uint8 token0Decimals = _token0 == address(0)
            ? NATIVE_COIN_DECIMALS
            : IERC20Metadata(_token0).decimals();
        uint8 token1Decimals = IERC20Metadata(_token1).decimals();

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

        uint256 deviation = FullMath.mulDivRoundingUp(
            FullMath.mulDivRoundingUp(
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
        return _managerBalance(true);
    }

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return managerFee1 amount of token1 that manager earned.
    function managerBalance1()
        external
        view
        returns (uint256 managerFee1)
    {
        return _managerBalance(false);
    }

    // #endregion view functions.

    // #region internal functions.

    function _managerBalance(
        bool isToken0_
    ) internal view returns (uint256 managerBalance) {
        PoolKey memory _poolKey = poolKey;
        PoolRange[] memory poolRanges =
            UniswapV4._getPoolRanges(_ranges, _poolKey);

        (uint256 leftOver0, uint256 leftOver1) =
            IUniV4StandardModule(this)._getLeftOvers(_poolKey);

        (uint160 sqrtPriceX96_,,,) =
            poolManager.getSlot0(PoolIdLibrary.toId(_poolKey));

        (,, uint256 fee0, uint256 fee1) = UnderlyingV4
            .totalUnderlyingAtPriceWithFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                self: address(this),
                leftOver0: leftOver0,
                leftOver1: leftOver1
            }),
            sqrtPriceX96_
        );

        (fee0, fee1) = isInversed ? (fee1, fee0) : (fee0, fee1);

        managerBalance = isToken0_
            ? FullMath.mulDivRoundingUp(fee0, managerFeePIPS, PIPS)
            : FullMath.mulDivRoundingUp(fee1, managerFeePIPS, PIPS);
    }

    function _unlockCallback(
        Action action_,
        bytes memory data_
    ) internal returns (bytes memory) {
        if (action_ == Action.WITHDRAW) {
            (address receiver, uint256 proportion) =
                abi.decode(data_, (address, uint256));
            return IUniV4StandardModule(this).withdraw(
                Withdraw({
                    receiver: receiver,
                    proportion: proportion,
                    amount0: 0,
                    amount1: 0,
                    fee0: 0,
                    fee1: 0
                }),
                _ranges,
                _activeRanges
            );
        }
        if (action_ == Action.REBALANCE) {
            (
                LiquidityRange[] memory liquidityRanges,
                SwapPayload memory swapPayload
            ) = abi.decode(data_, (LiquidityRange[], SwapPayload));
            return IUniV4StandardModule(this).rebalance(
                poolKey,
                liquidityRanges,
                swapPayload,
                _ranges,
                _activeRanges
            );
        }
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

    // #endregion internal functions.
}
