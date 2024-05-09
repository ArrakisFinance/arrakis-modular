// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IValantisSOTModule} from
    "../interfaces/IValantisSOTModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {ISovereignPool} from "../interfaces/ISovereignPool.sol";
import {ISOT} from "@valantis-sot/contracts/interfaces/ISOT.sol";
import {BASE, PIPS} from "../constants/CArrakis.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

/// @dev BeaconProxy be careful for changing implementation with upgrade.
abstract contract ValantisModule is
    IArrakisLPModule,
    IValantisSOTModule,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20Metadata;

    // #region public properties.

    IArrakisMetaVault public metaVault;
    ISovereignPool public pool;
    ISOT public alm;
    IERC20Metadata public token0;
    IERC20Metadata public token1;
    /// @dev should we change it to mutable state variable,
    /// and settable by who?
    uint24 public maxSlippage;

    // #endregion public properties.

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;
    uint256 internal _managerFeePIPS;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault)) {
            revert OnlyMetaVault(msg.sender, address(metaVault));
        }
        _;
    }

    modifier onlyManager() {
        address manager = metaVault.manager();
        if (manager != msg.sender) {
            revert OnlyManager(msg.sender, manager);
        }
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    // #endregion modifiers.

    constructor(address guardian_) {
        if (guardian_ == address(0)) revert AddressZero();

        _guardian = guardian_;

        _disableInitializers();
    }

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the valantis module.
    /// who can call deposit and withdraw functions.
    /// @param pool_ address of the valantis sovereign pool.

    /// @param init0_ initial amount of token0 to provide to valantis module.
    /// @param init1_ initial amount of token1 to provide to valantis module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param metaVault_ address of the meta vault
    function initialize(
        address pool_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_,
        address metaVault_
    ) external initializer {
        if (metaVault_ == address(0)) revert AddressZero();
        if (pool_ == address(0)) revert AddressZero();
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
        if (maxSlippage_ > PIPS / 10) {
            revert MaxSlippageGtTenPercent();
        }

        metaVault = IArrakisMetaVault(metaVault_);
        pool = ISovereignPool(pool_);

        token0 = IERC20Metadata(metaVault.token0());
        token1 = IERC20Metadata(metaVault.token1());

        _init0 = init0_;
        _init1 = init1_;

        maxSlippage = maxSlippage_;
    }

    function initializePosition() external onlyMetaVault {
        uint256 amount0 = token0.balanceOf(address(this));
        uint256 amount1 = token1.balanceOf(address(this));

        // #region increase allowance to alm.

        if (amount0 > 0) {
            token0.safeIncreaseAllowance(address(alm), amount0);
        }
        if (amount1 > 0) {
            token1.safeIncreaseAllowance(address(alm), amount1);
        }

        // #endregion increase allowance to alm.

        alm.depositLiquidity(amount0, amount1, 0, 0);

        emit LogInitializePosition(amount0, amount1);
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

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = pool.getReserves();

            amount0 = FullMath.mulDiv(proportion_, _amt0, BASE);
            amount1 = FullMath.mulDiv(proportion_, _amt1, BASE);
        }

        if (amount0 == 0 && amount1 == 0) revert AmountsZeros();

        // #endregion effects.

        // #region interactions.

        alm.withdrawLiquidity(amount0, amount1, receiver_, 0, 0);

        // #endregion interactions.

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        address manager = metaVault.manager();

        pool.claimPoolManagerFees(0, 0);

        amount0 = token0.balanceOf(address(this));
        amount1 = token1.balanceOf(address(this));

        // #region transfer tokens to manager.

        if (amount0 > 0) token0.safeTransfer(manager, amount0);

        if (amount1 > 0) token1.safeTransfer(manager, amount1);

        // #endregion transfer tokens to manager.

        emit LogWithdrawManagerBalance(manager, amount0, amount1);
    }

    /// @notice function used to set manager fees.
    /// @param newFeePIPS_ new fee that will be applied.
    function setManagerFeePIPS(uint256 newFeePIPS_)
        external
        whenNotPaused
    {
        uint256 _oldFee = _managerFeePIPS;

        // #region checks.

        if (msg.sender != metaVault.manager()) {
            revert OnlyManager(msg.sender, metaVault.manager());
        }

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        _managerFeePIPS = newFeePIPS_;

        if (address(alm) != address(0) || _oldFee != 0) {
            pool.setPoolManagerFeeBips(newFeePIPS_ / 1e2);
        }

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_);
    }

    /// @notice fucntion used to set range on valantis AMM
    /// @param sqrtPriceLowX96_ lower bound of the range in sqrt price.
    /// @param sqrtPriceHighX96_ upper bound of the range in sqrt price.
    /// @param expectedSqrtSpotPriceLowerX96_ expected upper limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    /// @param expectedSqrtSpotPriceUpperX96_ expected lower limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    function setPriceBounds(
        uint160 sqrtPriceLowX96_,
        uint160 sqrtPriceHighX96_,
        uint160 expectedSqrtSpotPriceUpperX96_,
        uint160 expectedSqrtSpotPriceLowerX96_
    ) external onlyManager {
        alm.setPriceBounds(
            sqrtPriceLowX96_,
            sqrtPriceHighX96_,
            expectedSqrtSpotPriceLowerX96_,
            expectedSqrtSpotPriceUpperX96_
        );
    }

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return fees0 amount of token0 that manager earned.
    function managerBalance0()
        external
        view
        returns (uint256 fees0)
    {
        (fees0,) = pool.getPoolManagerFees();
    }

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return fees1 amount of token1 that manager earned.
    function managerBalance1()
        external
        view
        returns (uint256 fees1)
    {
        (, fees1) = pool.getPoolManagerFees();
    }

    /// @notice function used to get manager fees.
    /// @return managerFeePIPS amount of token1 that manager earned.
    function managerFeePIPS() external view returns (uint256) {
        return _managerFeePIPS;
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
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return pool.getReserves();
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
        return alm.getReservesAtPrice(priceX96_);
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    function validateRebalance(
        IOracleWrapper,
        uint24
    ) external view virtual {}

    // #region view functions.

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    // #endregion view functions.
}
