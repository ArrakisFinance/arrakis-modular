// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IUniswapV3StandardModule} from
    "../interfaces/IUniswapV3StandardModule.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {IUniswapV3PoolVariant} from
    "../interfaces/IUniswapV3PoolVariant.sol";
import {IUniswapV3FactoryVariant} from
    "../interfaces/IUniswapV3FactoryVariant.sol";
import {
    PIPS,
    BASE,
    NATIVE_COIN,
    TEN_PERCENT
} from "../constants/CArrakis.sol";
import {
    Rebalance,
    Range,
    PositionLiquidity,
    SwapPayload,
    UnderlyingPayloadV3
} from "../structs/SUniswapV3.sol";
import {UnderlyingV3} from "../libraries/UnderlyingV3.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";

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

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

/// @notice this module can set Uniswap v3 pool that have a generic hook,
/// that don't require specific action to become liquidity provider.
/// @dev due to native coin standard difference between Uniswap and arrakis,
/// we are assuming that all inputed amounts are using arrakis vault token0/token1
/// as reference. Internal logic of UniswapV3StandardModule will handle the conversion or
/// use the pool address to interact with the pool.
abstract contract UniswapV3StandardModule is
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    IArrakisLPModule,
    IArrakisLPModuleID,
    IUniswapV3StandardModule
{
    using SafeERC20 for IERC20Metadata;
    using Address for address;

    // #region public immutables.
    address public immutable factory;
    // #endregion public immutables.

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
    /// @notice manager fees share.
    uint256 public managerFeePIPS;
    /// oracle that will be used to proctect rebalances against attacks.
    IOracleWrapper public oracle;
    /// @notice max slippage that can occur during swap rebalance.
    uint24 public maxSlippage;
    /// @notice pool address of the module.
    address public pool;
    // /// @notice receiver of the rewards.
    // address public rewardReceiver;

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

    modifier onlyMetaVaultOwner() {
        if (msg.sender != IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }
        _;
    }

    // #endregion modifiers.

    constructor(address guardian_, address factory_) {
        // #region checks.
        if (guardian_ == address(0) || factory_ == address(0)) {
            revert AddressZero();
        }
        // #endregion checks.

        factory = factory_;
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
    /// for initializing the Uniswap swap v3 standard module.
    /// @param init0_ initial amount of token0 to provide to Uniswap swap standard module.
    /// @param init1_ initial amount of token1 to provide to Uniswap swap standard module.
    /// @param fee_ fee of Uniswap swap v3 pool that will be used by the module.
    /// @param oracle_ address of the oracle used by the Uniswap swap v3 standard module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param metaVault_ address of the meta vault.
    function initialize(
        uint256 init0_,
        uint256 init1_,
        uint24 fee_,
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address rewardReceiver_,
        address metaVault_
    ) external initializer {
        // #region checks.
        if (
            metaVault_ == address(0) || address(oracle_) == address(0)
                || rewardReceiver_ == address(0)
        ) revert AddressZero();
        if (maxSlippage_ > TEN_PERCENT) {
            revert MaxSlippageGtTenPercent();
        }
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
        // #endregion checks.

        metaVault = IArrakisMetaVault(metaVault_);
        oracle = oracle_;
        maxSlippage = maxSlippage_;

        address _token0 = IArrakisMetaVault(metaVault_).token0();
        address _token1 = IArrakisMetaVault(metaVault_).token1();

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);

        // Uniswap V3 doesn't support native coin
        if (
            address(token0) == NATIVE_COIN
                || address(token1) == NATIVE_COIN
        ) {
            revert NativeCoinNotSupported();
        }

        _init0 = init0_;
        _init1 = init1_;

        // #region pool initialization.

        pool = IUniswapV3FactoryVariant(factory).getPool(
            address(token0), address(token1), fee_
        );

        if (pool == address(0)) revert PoolNotFound();

        // #endregion pool initialization.

        __ReentrancyGuard_init();
        __Pausable_init();
    }

    /// @notice function used to initialize the module
    /// when a module switch happen
    function initializePosition(
        bytes calldata
    ) external virtual onlyMetaVault {
        // @dev left over will sit on the module.
    }

    // #region vault owner functions.

    // /// @inheritdoc IUniswapV3StandardModule
    // function claimRewards(
    //     IUniswapDistributor.ClaimParams[] calldata params_,
    //     IUniswapDistributor.ClaimEscrowed[] calldata escrowed_,
    //     address receiver_
    // ) external onlyMetaVaultOwner nonReentrant whenNotPaused {
    //     // #region checks.

    //     if (receiver_ == address(0)) {
    //         revert AddressZero();
    //     }

    //     if (params_.length == 0 && escrowed_.length == 0) {
    //         revert ClaimParamsLengthZero();
    //     }

    //     // #endregion checks.

    //     // #region escrowed.

    //     uint256 length = escrowed_.length;

    //     for (uint256 i; i < length; i++) {
    //         IUniswapDistributor.ClaimEscrowed memory escrowed =
    //             escrowed_[i];

    //         if (escrowed.token == address(0)) {
    //             revert AddressZero();
    //         }

    //         if (
    //             escrowed.token == address(token0)
    //                 || escrowed.token == address(token1)
    //         ) {
    //             revert RewardTokenNotAllowed();
    //         }

    //         uint256 balanceToken = IERC20Metadata(escrowed.token)
    //             .balanceOf(address(this));

    //         if (balanceToken < escrowed.amount) {
    //             revert InsufficientFunds();
    //         }

    //         IERC20Metadata(escrowed.token).safeTransfer(
    //             receiver_, escrowed.amount
    //         );

    //         emit LogClaimEscrowed(escrowed.token, escrowed.amount);
    //     }

    //     // #endregion escrowed.

    //     length = params_.length;
    //     uint256[] memory balances = new uint256[](length);

    //     for (uint256 i; i < length; i++) {
    //         IUniswapDistributor.ClaimParams memory param = params_[i];

    //         balances[i] =
    //             IERC20Metadata(param.token).balanceOf(address(this));
    //     }

    //     // #region claim.

    //     distributor.claim(params_);

    //     // #endregion claim.

    //     address _rewardReceiver = rewardReceiver;
    //     uint256 _managerFeePIPS = managerFeePIPS;

    //     for (uint256 i; i < length; i++) {
    //         IUniswapDistributor.ClaimParams memory param = params_[i];
    //         uint256 balance = IERC20Metadata(param.token).balanceOf(
    //             address(this)
    //         ) - balances[i];

    //         if (balance == 0) {
    //             continue;
    //         }

    //         uint256 managerShare =
    //             FullMath.mulDiv(balance, _managerFeePIPS, PIPS);

    //         IERC20Metadata(param.token).safeTransfer(
    //             receiver_, balance - managerShare
    //         );
    //         IERC20Metadata(param.token).safeTransfer(
    //             _rewardReceiver, managerShare
    //         );

    //         emit LogClaimReward(param.token, balance - managerShare);
    //         emit LogClaimManagerReward(param.token, managerShare);
    //     }
    // }

    // function claimManagerRewards(
    //     IUniswapDistributor.ClaimParams[] calldata params_
    // ) external onlyManager nonReentrant whenNotPaused {
    //     // #region checks.

    //     uint256 length = params_.length;

    //     if (length == 0) {
    //         revert ClaimParamsLengthZero();
    //     }

    //     // #endregion checks.

    //     uint256[] memory balances = new uint256[](length);

    //     for (uint256 i; i < length; i++) {
    //         IUniswapDistributor.ClaimParams memory param = params_[i];

    //         balances[i] =
    //             IERC20Metadata(param.token).balanceOf(address(this));
    //     }

    //     // #region claim.

    //     distributor.claim(params_);

    //     // #endregion claim.

    //     address _rewardReceiver = rewardReceiver;
    //     uint256 _managerFeePIPS = managerFeePIPS;

    //     for (uint256 i; i < length; i++) {
    //         IUniswapDistributor.ClaimParams memory param = params_[i];
    //         uint256 balance = IERC20Metadata(param.token).balanceOf(
    //             address(this)
    //         ) - balances[i];

    //         if (balance == 0) {
    //             continue;
    //         }

    //         uint256 managerShare =
    //             FullMath.mulDiv(balance, _managerFeePIPS, PIPS);

    //         IERC20Metadata(param.token).safeTransfer(
    //             _rewardReceiver, managerShare
    //         );

    //         emit LogClaimManagerReward(param.token, managerShare);
    //     }
    // }

    // function setReceiver(
    //     address newReceiver_
    // ) external whenNotPaused {
    //     address manager = metaVault.manager();

    //     if (IOwnable(manager).owner() != msg.sender) {
    //         revert OnlyManagerOwner();
    //     }

    //     address oldReceiver = rewardReceiver;
    //     if (newReceiver_ == address(0)) {
    //         revert AddressZero();
    //     }

    //     if (oldReceiver == newReceiver_) {
    //         revert SameReceiver();
    //     }

    //     rewardReceiver = newReceiver_;

    //     emit LogSetReceiver(oldReceiver, newReceiver_);
    // }

    /// @inheritdoc IUniswapV3StandardModule
    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external nonReentrant whenNotPaused onlyMetaVaultOwner {
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

            IERC20Metadata(token).forceApprove(spender_, amount);
        }

        emit LogApproval(spender_, tokens_, amounts_);
    }

    // #endregion vault owner functions.

    // #region only manager functions.

    /// @notice function used to set the pool for the module.
    /// @param fee_ fee of the pool of the Uniswap v3 pool that will be used by the module.
    function setPool(
        uint24 fee_,
        Rebalance calldata rebalance_
    ) external onlyManager nonReentrant whenNotPaused {
        address _pool = pool;

        address pool_ = IUniswapV3FactoryVariant(factory).getPool(
            address(token0), address(token1), fee_
        );

        if (pool_ == address(0)) revert PoolNotFound();
        if (pool_ == _pool) revert SamePool();

        // #region remove any remaining liquidity on the previous pool.

        _removeAllLiquidity();

        // #endregion remove any remaining liquidity on the previous pool.

        // #region set Pool.

        pool = pool_;

        // #endregion set Pool.

        // #region do rebalance.

        (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        ) = _internalRebalance(rebalance_);

        if (rebalance_.minDeposit0 > amount0Minted) {
            revert MintToken0();
        }
        if (rebalance_.minDeposit1 > amount1Minted) {
            revert MintToken1();
        }
        if (rebalance_.minBurn0 > amount0Burned) revert BurnToken0();
        if (rebalance_.minBurn1 > amount1Burned) revert BurnToken1();

        // #endregion do rebalance.

        emit LogSetPool(_pool, pool_, rebalance_);
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

        (amount0, amount1) = _withdraw(receiver_, proportion_);

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    /// @notice function used to rebalance the inventory of the module.
    /// @param rebalance_ rebalance parameters including burns, mints, and swap.
    function rebalance(
        Rebalance calldata rebalance_
    ) external onlyManager nonReentrant whenNotPaused {
        (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        ) = _internalRebalance(rebalance_);

        if (rebalance_.minDeposit0 > amount0Minted) {
            revert MintToken0();
        }
        if (rebalance_.minDeposit1 > amount1Minted) {
            revert MintToken1();
        }
        if (rebalance_.minBurn0 > amount0Burned) revert BurnToken0();
        if (rebalance_.minBurn1 > amount1Burned) revert BurnToken1();
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
        uint256 managerFeePIPS_ = managerFeePIPS;
        uint256 fee0;
        uint256 fee1;
        address manager = metaVault.manager();
        address _pool = pool;
        // Collect fees from all positions
        uint256 length = _ranges.length;
        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            bytes32 positionId = UnderlyingV3.getPositionId(
                address(this), range.lowerTick, range.upperTick
            );

            if (_activeRanges[positionId]) {
                IUniswapV3Pool(_pool).burn(
                    range.lowerTick, range.upperTick, 0
                );
                (uint256 collected0, uint256 collected1) =
                IUniswapV3Pool(_pool).collect(
                    address(this),
                    range.lowerTick,
                    range.upperTick,
                    type(uint128).max,
                    type(uint128).max
                );

                fee0 += collected0;
                fee1 += collected1;
            }
        }

        amount0 = FullMath.mulDiv(fee0, managerFeePIPS_, PIPS);
        amount1 = FullMath.mulDiv(fee1, managerFeePIPS_, PIPS);

        if (amount0 > 0) {
            token0.safeTransfer(manager, amount0);
        }
        if (amount1 > 0) {
            token1.safeTransfer(manager, amount1);
        }
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

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata
    ) external override {
        if (msg.sender != pool) revert OnlyPool();

        if (amount0Owed > 0) {
            token0.safeTransfer(msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            token1.safeTransfer(msg.sender, amount1Owed);
        }
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
        public
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
        return (_init0, _init1);
    }

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        (amount0, amount1,,) = UnderlyingV3.totalUnderlyingWithFees(
            UnderlyingPayloadV3({
                ranges: _ranges,
                pool: pool,
                self: address(this),
                leftOver0: _token0.balanceOf(address(this)),
                leftOver1: _token1.balanceOf(address(this)),
                token0: address(_token0),
                token1: address(_token1)
            })
        );
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1,,) = UnderlyingV3
            .totalUnderlyingAtPriceWithFees(
            UnderlyingPayloadV3({
                ranges: _ranges,
                pool: pool,
                self: address(this),
                leftOver0: token0.balanceOf(address(this)),
                leftOver1: token1.balanceOf(address(this)),
                token0: address(token0),
                token1: address(token1)
            }),
            priceX96_
        );
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
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;
        // check if pool current price is not too far from oracle price.
        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(pool).slot0();

        uint8 token0Decimals = _token0.decimals();
        uint8 token1Decimals = _token1.decimals();

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

        // #region get oracle price.
        uint256 oraclePrice = oracle_.getPrice0();
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
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        (,, uint256 fee0, uint256 fee1) = UnderlyingV3
            .totalUnderlyingWithFees(
            UnderlyingPayloadV3({
                ranges: _ranges,
                pool: pool,
                self: address(this),
                leftOver0: _token0.balanceOf(address(this)),
                leftOver1: _token1.balanceOf(address(this)),
                token0: address(_token0),
                token1: address(_token1)
            })
        );

        if (isToken0_) {
            (managerBalance,) = UnderlyingV3.subtractAdminFees(
                fee0, fee1, managerFeePIPS
            );
        } else {
            (, managerBalance) = UnderlyingV3.subtractAdminFees(
                fee0, fee1, managerFeePIPS
            );
        }
    }

    function _withdraw(
        address receiver_,
        uint256 proportion_
    ) internal returns (uint256 amount0, uint256 amount1) {
        // Remove liquidity proportionally from all positions
        uint256 amount0Collected;
        uint256 amount1Collected;

        uint256 leftOver0 = token0.balanceOf(address(this));
        uint256 leftOver1 = token1.balanceOf(address(this));

        {
            uint256 length = _ranges.length;
            for (uint256 i; i < length; i++) {
                Range memory range = _ranges[length - i - 1];
                bytes32 positionId = UnderlyingV3.getPositionId(
                    address(this), range.lowerTick, range.upperTick
                );

                if (_activeRanges[positionId]) {
                    // Get current liquidity for this position
                    (uint128 liquidity,,,,) =
                        IUniswapV3Pool(pool).positions(positionId);

                    if (liquidity > 0) {
                        uint128 liquidityToRemove = SafeCast.toUint128(
                            FullMath.mulDiv(
                                uint256(liquidity), proportion_, BASE
                            )
                        );

                        if (liquidityToRemove > 0) {
                            (uint256 burn0, uint256 burn1) =
                            IUniswapV3Pool(pool).burn(
                                range.lowerTick,
                                range.upperTick,
                                liquidityToRemove
                            );

                            amount0 += burn0;
                            amount1 += burn1;

                            (uint256 collected0, uint256 collected1) =
                            IUniswapV3Pool(pool).collect(
                                address(this),
                                range.lowerTick,
                                range.upperTick,
                                type(uint128).max,
                                type(uint128).max
                            );

                            amount0Collected += collected0;
                            amount1Collected += collected1;
                        }

                        if (liquidityToRemove == liquidity) {
                            _activeRanges[positionId] = false;
                            _ranges[length - i - 1] =
                                _ranges[_ranges.length - 1];
                            _ranges.pop();
                        }
                    }
                }
            }
        }

        // #region get manager share.

        uint256 managerFeePIPS_ = managerFeePIPS;

        {
            address manager = metaVault.manager();

            uint256 fee0 = amount0Collected - amount0;
            uint256 fee1 = amount1Collected - amount1;

            uint256 managerFee0 =
                FullMath.mulDiv(fee0, managerFeePIPS_, PIPS);
            uint256 managerFee1 =
                FullMath.mulDiv(fee1, managerFeePIPS_, PIPS);

            if (managerFee0 > 0) {
                token0.safeTransfer(manager, managerFee0);
            }
            if (managerFee1 > 0) {
                token1.safeTransfer(manager, managerFee1);
            }

            amount0 = amount0
                + FullMath.mulDiv(fee0 - managerFee0, proportion_, BASE)
                + FullMath.mulDiv(leftOver0, proportion_, BASE);
            amount1 = amount1
                + FullMath.mulDiv(fee1 - managerFee1, proportion_, BASE)
                + FullMath.mulDiv(leftOver1, proportion_, BASE);
        }

        // #endregion get manager share.

        if (amount0 > 0) {
            token0.safeTransfer(receiver_, amount0);
        }
        if (amount1 > 0) {
            token1.safeTransfer(receiver_, amount1);
        }
    }

    function _internalRebalance(
        Rebalance memory rebalance_
    )
        internal
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        )
    {
        uint256 amount0Collected;
        uint256 amount1Collected;

        uint256 length = rebalance_.burns.length;

        // Burn liquidity from specified ranges
        for (uint256 i; i < length; i++) {
            PositionLiquidity memory burn = rebalance_.burns[i];

            bytes32 positionId = UnderlyingV3.getPositionId(
                address(this),
                burn.range.lowerTick,
                burn.range.upperTick
            );

            if (_activeRanges[positionId]) {
                (uint128 liquidity,,,,) =
                    IUniswapV3Pool(pool).positions(positionId);

                (uint256 burn0, uint256 burn1) = IUniswapV3Pool(pool)
                    .burn(
                    burn.range.lowerTick,
                    burn.range.upperTick,
                    burn.liquidity
                );
                amount0Burned += burn0;
                amount1Burned += burn1;

                (uint256 collected0, uint256 collected1) =
                IUniswapV3Pool(pool).collect(
                    address(this),
                    burn.range.lowerTick,
                    burn.range.upperTick,
                    type(uint128).max,
                    type(uint128).max
                );

                amount0Collected += collected0;
                amount1Collected += collected1;

                if (burn.liquidity == liquidity) {
                    (, uint256 index) =
                        UnderlyingV3.rangeExists(_ranges, burn.range);

                    _activeRanges[positionId] = false;
                    _ranges[index] = _ranges[_ranges.length - 1];
                    _ranges.pop();
                }
            }
        }

        // #region collect manager fees.
        {
            uint256 managerFeePIPS_ = managerFeePIPS;
            address manager = metaVault.manager();

            uint256 fee0 = amount0Collected - amount0Burned;
            uint256 fee1 = amount1Collected - amount1Burned;

            uint256 managerFee0 =
                FullMath.mulDiv(fee0, managerFeePIPS_, PIPS);
            uint256 managerFee1 =
                FullMath.mulDiv(fee1, managerFeePIPS_, PIPS);

            if (managerFee0 > 0) {
                token0.safeTransfer(manager, managerFee0);
            }
            if (managerFee1 > 0) {
                token1.safeTransfer(manager, managerFee1);
            }
        }
        // #endregion collect manager fees.

        // Execute swap if needed
        if (rebalance_.swap.amountIn > 0) {
            _executeSwap(rebalance_.swap);
        }

        // Mint liquidity to specified ranges
        for (uint256 i; i < rebalance_.mints.length; i++) {
            PositionLiquidity memory mint = rebalance_.mints[i];
            if (mint.liquidity > 0) {
                (uint256 mint0, uint256 mint1) = IUniswapV3Pool(pool)
                    .mint(
                    address(this),
                    mint.range.lowerTick,
                    mint.range.upperTick,
                    mint.liquidity,
                    ""
                );
                amount0Minted += mint0;
                amount1Minted += mint1;

                bytes32 positionId = UnderlyingV3.getPositionId(
                    address(this),
                    mint.range.lowerTick,
                    mint.range.upperTick
                );

                // Add to ranges array if not already present
                _addRangeIfNotExists(positionId, mint.range);
            }
        }

        emit LogRebalance(
            rebalance_.burns,
            rebalance_.mints,
            amount0Minted,
            amount1Minted,
            amount0Burned,
            amount1Burned
        );
    }

    function _executeSwap(
        SwapPayload memory swapPayload_
    ) internal {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        _checkMinReturn(
            swapPayload_.zeroForOne,
            swapPayload_.expectedMinReturn,
            swapPayload_.amountIn,
            _token0.decimals(),
            _token1.decimals()
        );

        uint256 balance;

        if (swapPayload_.zeroForOne) {
            _token0.forceApprove(
                swapPayload_.router, swapPayload_.amountIn
            );

            balance = _token1.balanceOf(address(this));
        } else {
            _token1.forceApprove(
                swapPayload_.router, swapPayload_.amountIn
            );

            balance = _token0.balanceOf(address(this));
        }

        if (swapPayload_.router == address(metaVault)) {
            revert WrongRouter();
        }

        {
            swapPayload_.router.functionCall(swapPayload_.payload);
        }

        if (swapPayload_.zeroForOne) {
            balance = _token1.balanceOf(address(this)) - balance;

            if (swapPayload_.expectedMinReturn > balance) {
                revert SlippageTooHigh();
            }

            _token0.forceApprove(swapPayload_.router, 0);
        } else {
            balance = _token0.balanceOf(address(this)) - balance;

            if (swapPayload_.expectedMinReturn > balance) {
                revert SlippageTooHigh();
            }

            _token1.forceApprove(swapPayload_.router, 0);
        }
    }

    function _removeAllLiquidity() internal {
        uint256 length = _ranges.length;
        uint256 fee0;
        uint256 fee1;
        for (uint256 i; i < length; i++) {
            Range memory range = _ranges[i];
            bytes32 positionId = UnderlyingV3.getPositionId(
                address(this), range.lowerTick, range.upperTick
            );

            if (_activeRanges[positionId]) {
                (uint128 liquidity,,,,) =
                    IUniswapV3Pool(pool).positions(positionId);

                if (liquidity > 0) {
                    (uint256 burn0, uint256 burn1) = IUniswapV3Pool(
                        pool
                    ).burn(
                        range.lowerTick, range.upperTick, liquidity
                    );

                    (uint256 collected0, uint256 collected1) =
                    IUniswapV3Pool(pool).collect(
                        address(this),
                        range.lowerTick,
                        range.upperTick,
                        type(uint128).max,
                        type(uint128).max
                    );

                    fee0 += collected0 - burn0;
                    fee1 += collected1 - burn1;
                }

                _activeRanges[positionId] = false;
            }
        }

        // #region collect manager fees.
        {
            uint256 managerFeePIPS_ = managerFeePIPS;
            address manager = metaVault.manager();

            uint256 managerFee0 =
                FullMath.mulDiv(fee0, managerFeePIPS_, PIPS);
            uint256 managerFee1 =
                FullMath.mulDiv(fee1, managerFeePIPS_, PIPS);

            if (managerFee0 > 0) {
                token0.safeTransfer(manager, managerFee0);
            }
            if (managerFee1 > 0) {
                token1.safeTransfer(manager, managerFee1);
            }
        }

        // Clear ranges array
        delete _ranges;
    }

    function _addRangeIfNotExists(
        bytes32 positionId_,
        Range memory range_
    ) internal {
        bytes32 rangeHash =
            keccak256(abi.encode(range_.lowerTick, range_.upperTick));

        for (uint256 i; i < _ranges.length; i++) {
            Range memory range = _ranges[i];
            if (
                keccak256(
                    abi.encode(range.lowerTick, range.upperTick)
                ) == rangeHash
            ) {
                return; // Range already exists
            }
        }

        _activeRanges[positionId_] = true;
        _ranges.push(range_);
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

    // #endregion internal functions.
}
