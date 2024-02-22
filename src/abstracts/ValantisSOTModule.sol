// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IValantisSOTModule} from "../interfaces/IValantisSOTModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {ISovereignPool} from "../interfaces/ISovereignPool.sol";
import {ISOT} from "../interfaces/ISOT.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {PIPS} from "../constants/CArrakis.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

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
    IOracleWrapper public oracle;

    // #endregion public properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;
    address internal _guardian;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault))
            revert OnlyMetaVault(msg.sender, address(metaVault));
        _;
    }

    modifier onlyManager() {
        address manager = metaVault.manager();
        if (manager != msg.sender) revert OnlyManager(msg.sender, manager);
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    // #endregion modifiers.

    function initialize(
        address metaVault_,
        address pool_,
        address alm_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_,
        address oracle_,
        address guardian_
    ) external initializer {
        if (metaVault_ == address(0)) revert AddressZero();
        if (pool_ == address(0)) revert AddressZero();
        if (alm_ == address(0)) revert AddressZero();
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
        if (maxSlippage_ > PIPS / 10) revert MaxSlippageGtTenPercent();
        if (oracle_ == address(0)) revert AddressZero();
        if (guardian_ == address(0)) revert AddressZero();

        metaVault = IArrakisMetaVault(metaVault_);
        pool = ISovereignPool(pool_);
        alm = ISOT(alm_);

        token0 = IERC20Metadata(metaVault.token0());
        token1 = IERC20Metadata(metaVault.token1());

        _init0 = init0_;
        _init1 = init1_;

        maxSlippage = maxSlippage_;
        oracle = IOracleWrapper(oracle_);
        _guardian = guardian_;
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
        external
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();
        if (proportion_ > PIPS) revert ProportionGtPIPS();

        // #endregion checks.

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = pool.getReserves();

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        if (amount0 == 0 && amount1 == 0) revert AmountsZeros();

        // #endregion effects.

        // NOTE:  check with Ed for rebase tokens.

        uint256 balance0 = token0.balanceOf(receiver_);
        uint256 balance1 = token1.balanceOf(receiver_);

        // #region interactions.

        alm.withdrawLiquidity(amount0, amount1, receiver_, 0, 0);

        // #endregion interactions.

        uint256 _actual0 = token0.balanceOf(receiver_) - balance0;
        uint256 _actual1 = token1.balanceOf(receiver_) - balance1;

        // #region assertions.

        if (_actual0 != amount0)
            revert Actual0DifferentExpected(_actual0, amount0);
        if (_actual1 != amount1)
            revert Actual1DifferentExpected(_actual1, amount1);

        // #endregion assertions.

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

        (amount0, amount1) = pool.claimPoolManagerFees(0, 0);

        // #region transfer tokens to manager.

        if (amount0 > 0) token0.safeTransfer(manager, amount0);

        if (amount1 > 0) token1.safeTransfer(manager, amount1);

        // #endregion transfer tokens to manager.

        emit LogWithdrawManagerBalance(manager, amount0, amount1);
    }

    /// @notice function used to set manager fees.
    /// @param newFeePIPS_ new fee that will be applied.
    function setManagerFeePIPS(uint256 newFeePIPS_) external whenNotPaused {
        uint256 _oldFee = pool.poolManagerFeeBips();

        // #region checks.

        if (msg.sender != metaVault.manager())
            revert OnlyManager(msg.sender, metaVault.manager());

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        pool.setPoolManagerFeeBips(newFeePIPS_ / 1e2);

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_ / 1e2);
    }

    /// @notice function to swap token0->token1 or token1->token0 and then change
    /// inventory.
    /// @param zeroForOne_ boolean if true token0->token1, if false token1->token0.
    /// @param expectedMinReturn_ minimum amount of tokenOut expected.
    /// @param amountIn_ amount of tokenIn used during swap.
    /// @param router_ address of routerSwapExecutor.
    /// @param expectedSqrtSpotPriceUpperX96_ upper bound of current price.
    /// @param expectedSqrtSpotPriceLowerX96_ lower bound of current price.
    /// @param payload_ data payload used for swapping.
    function swap(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        address router_,
        uint160 expectedSqrtSpotPriceUpperX96_,
        uint160 expectedSqrtSpotPriceLowerX96_,
        bytes calldata payload_
    ) external onlyManager whenNotPaused {
        // #region checks/effects.

        _checkMinReturn(
            zeroForOne_,
            expectedMinReturn_,
            amountIn_,
            token0.decimals(),
            token1.decimals()
        );

        // #endregion checks/effects.

        // #region interactions.

        uint256 _actual0;
        uint256 _actual1;
        uint256 _initBalance0;
        uint256 _initBalance1;

        {
            _initBalance0 = token0.balanceOf(address(this));
            _initBalance1 = token1.balanceOf(address(this));
            (uint256 _amt0, uint256 _amt1) = pool.getReserves();

            if (zeroForOne_) {
                if (_amt0 < amountIn_) revert NotEnoughToken0();
            } else if (_amt1 < amountIn_) revert NotEnoughToken1();

            alm.withdrawLiquidity(_amt0, _amt1, address(this), 0, 0);

            _actual0 = token0.balanceOf(address(this)) - _initBalance0;
            _actual1 = token1.balanceOf(address(this)) - _initBalance1;

            if (_actual0 != _amt0)
                revert Actual0DifferentExpected(_actual0, _amt0);
            if (_actual1 != _amt1)
                revert Actual1DifferentExpected(_actual1, _amt1);
        }

        if (zeroForOne_) {
            token0.safeIncreaseAllowance(router_, amountIn_);
        } else {
            token1.safeIncreaseAllowance(router_, amountIn_);
        }

        {
            (bool success, ) = router_.call(payload_);
            if (!success) revert SwapCallFailed();
        }

        // #endregion interactions.

        // #region assertions.

        uint256 balance0 = token0.balanceOf(address(this)) - _initBalance0;
        uint256 balance1 = token1.balanceOf(address(this)) - _initBalance1;

        if (zeroForOne_) {
            if (_actual1 + expectedMinReturn_ > balance1)
                revert SlippageTooHigh();
        } else {
            if (_actual0 + expectedMinReturn_ > balance0)
                revert SlippageTooHigh();
        }

        // #endregion assertions.

        // #region deposit.

        token0.safeIncreaseAllowance(address(alm), balance0);
        token1.safeIncreaseAllowance(address(alm), balance1);

        alm.depositLiquidity(balance0, balance1, expectedSqrtSpotPriceUpperX96_, expectedSqrtSpotPriceLowerX96_);

        // #endregion deposit.

        // #region assertions.

        {
            uint256 newbalance0 = token0.balanceOf(address(this)) - _initBalance0;
            uint256 newbalance1 = token1.balanceOf(address(this)) - _initBalance1;

            if (newbalance0 > 0) revert NotDepositedAllToken0();

            if (newbalance1 > 0) revert NotDepositedAllToken1();
        }

        // #endregion assertions.

        emit LogSwap(_actual0, _actual1, balance0, balance1);
    }

    /// @notice fucntion used to set range on valantis AMM
    /// @param sqrtPriceLowX96_ lower bound of the range in sqrt price.
    /// @param sqrtPriceHighX96_ upper bound of the range in sqrt price.
    /// @param expectedSqrtSpotPriceUpperX96_ expected lower limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    /// @param expectedSqrtSpotPriceLowerX96_ expected upper limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    function setPriceBounds(
        uint128 sqrtPriceLowX96_,
        uint128 sqrtPriceHighX96_,
        uint160 expectedSqrtSpotPriceUpperX96_,
        uint160 expectedSqrtSpotPriceLowerX96_
    ) external onlyManager {
        alm.setPriceBounds(
            sqrtPriceLowX96_,
            sqrtPriceHighX96_,
            expectedSqrtSpotPriceUpperX96_,
            expectedSqrtSpotPriceLowerX96_
        );
    }

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return fees0 amount of token0 that manager earned.
    function managerBalance0() external view returns (uint256 fees0) {
        (fees0, ) = pool.getPoolManagerFees();
    }

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return fees1 amount of token1 that manager earned.
    function managerBalance1() external view returns (uint256 fees1) {
        (, fees1) = pool.getPoolManagerFees();
    }

    /// @notice function used to get manager fees.
    /// @return managerFeePIPS amount of token1 that manager earned.
    function managerFeePIPS() external view returns (uint256) {
        return pool.poolManagerFeeBips() * 1e2;
    }

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits() external view returns (uint256 init0, uint256 init1) {
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
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return alm.getReservesAtPrice(priceX96_);
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// @param oracle_ onchain oracle to check the current amm price against.
    /// @param maxDeviation_ maximum deviation tolerated by management.
    function validateRebalance(IOracleWrapper oracle_, uint24 maxDeviation_) external view {
        uint256 oraclePrice = oracle_.getPrice0();
        uint8 decimals0 = token0.decimals();

        uint256 sqrtSpotPriceX96;
        (sqrtSpotPriceX96,,) = alm.getAmmState();

        uint256 currentPrice;

        if (sqrtSpotPriceX96 <= type(uint128).max) {
            currentPrice = FullMath.mulDiv(
                sqrtSpotPriceX96 * sqrtSpotPriceX96,
                10 ** decimals0,
                2 ** 192
            );
        } else {
            currentPrice = FullMath.mulDiv(
                FullMath.mulDiv(sqrtSpotPriceX96, sqrtSpotPriceX96, 1 << 64),
                10 ** decimals0,
                1 << 128
            );
        }

        uint256 deviation = FullMath.mulDiv(
                currentPrice > oraclePrice
                    ? currentPrice - oraclePrice
                    : oraclePrice - currentPrice,
                PIPS,
                oraclePrice
            );

        if(deviation > maxDeviation_) revert OverMaxDeviation();
    }

    // #region view functions.

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
                    expectedMinReturn_,
                    10 ** decimals0_,
                    amountIn_
                ) <
                FullMath.mulDiv(oracle.getPrice0(), PIPS - maxSlippage, PIPS)
            ) revert ExpectedMinReturnTooLow();
        } else {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_,
                    10 ** decimals1_,
                    amountIn_
                ) <
                FullMath.mulDiv(oracle.getPrice1(), PIPS - maxSlippage, PIPS)
            ) revert ExpectedMinReturnTooLow();
        }
    }

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    // #endregion view functions.
}
