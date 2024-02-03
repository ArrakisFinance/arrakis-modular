// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePublic} from "../interfaces/IArrakisLPModulePublic.sol";
import {IValantisSOTModule} from "../interfaces/IValantisSOTModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {ISovereignPool} from "../interfaces/ISovereignPool.sol";
import {ISOT} from "../interfaces/ISOT.sol";
import {IDecimals} from "../interfaces/IDecimals.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {PIPS} from "../constants/CArrakis.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

/// @dev BeaconProxy becareful for changing implementation with upgrade.
contract ValantisModule is
    IArrakisLPModule,
    IArrakisLPModulePublic,
    IValantisSOTModule,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // #region public properties.

    IArrakisMetaVault public metaVault;
    ISovereignPool public pool;
    ISOT public alm;
    IERC20 public token0;
    IERC20 public token1;
    /// @dev should we change it to mutable state variable,
    /// and settable by who?
    uint24 public maxSlippage;
    IOracleWrapper public oracle;

    // #endregion public properties.

    // #region guardian functions.

    uint256 internal _init0;
    uint256 internal _init1;
    address internal _guardian;

    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

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

            if (_amt0 == 0 && _amt1 == 0) {
                _amt0 = _init0;
                _amt1 = _init1;
            }

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        // #endregion effects.

        maxSlippage = maxSlippage_;
        oracle = IOracleWrapper(oracle_);
        _guardian = guardian_;
    }

    // #region guardian functions.

    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

        token0.safeTransferFrom(depositor_, address(this), amount0);
        token1.safeTransferFrom(depositor_, address(this), amount1);

        // #endregion get the tokens from the depositor.

        // #region increase allowance to alm.

        token0.safeIncreaseAllowance(address(alm), amount0);
        token1.safeIncreaseAllowance(address(alm), amount1);

        // #endregion increase allowance to alm.

        alm.depositLiquidity(amount0, amount1, 0, 0);

        // #endregion interactions.

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

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
            (uint256 _amt0, uint256 _amt1) = alm.getReservesAtPrice(0);

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        // #endregion effects.

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

        // #region interactions.

        // TODO: add receiver to valantis interface.
        alm.withdrawLiquidity(amount0, amount1, receiver_, 0, 0);

        // #endregion interactions.

        uint256 _actual0 = token0.balanceOf(address(receiver_)) - balance0;
        uint256 _actual1 = token1.balanceOf(address(receiver_)) - balance1;

        // #region assertions.

        if (_actual0 != amount0)
            revert Actual0DifferentExpected(_actual0, amount0);
        if (_actual1 != amount1)
            revert Actual1DifferentExpected(_actual1, amount1);

        // #endregion assertions.

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

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

    function withdrawManagerBalance()
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        address manager = metaVault.manager();

        // #region checks.

        if (msg.sender != metaVault.manager())
            revert OnlyManager(msg.sender, metaVault.manager());

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        pool.setPoolManagerFeeBips(newFeePIPS_ / 1e2);

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_ / 1e2);
    }

    function setManagerFeePIPS(uint256 newFeePIPS_) external whenNotPaused {
        uint256 _oldFee = pool.poolManagerFeeBips();

        _checkMinReturn(
            zeroForOne_,
            expectedMinReturn_,
            amountIn_,
            IDecimals(address(token0)).decimals(),
            IDecimals(address(token1)).decimals()
        );

        // #endregion checks/effects.

        // #region interactions.

        uint256 _amt0;
        uint256 _amt1;
        uint256 _actual0;
        uint256 _actual1;

        {
            uint256 balance0 = token0.balanceOf(address(this));
            uint256 balance1 = token1.balanceOf(address(this));
            (_amt0, _amt1) = alm.getReservesAtPrice(0);

            if (zeroForOne_) {
                if (_amt0 < amountIn_) revert NotEnoughToken0();
            } else if (_amt1 < amountIn_) revert NotEnoughToken1();

    function swap(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        address router_,
        bytes calldata payload_
    ) external onlyManager whenNotPaused {
        // #region checks/effects.

        _checkMinReturn(
            zeroForOne_,
            expectedMinReturn_,
            amountIn_,
            IDecimals(address(token0)).decimals(),
            IDecimals(address(token1)).decimals()
        );

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

        uint256 balance0 = token0.balanceOf(address(this));
        uint256 balance1 = token1.balanceOf(address(this));

        if (zeroForOne_) {
            if (_actual1 + expectedMinReturn_ > balance1)
                revert SlippageTooHigh();

//             if (_actual0 != _amt0)
//                 revert Actual0DifferentExpected(_actual0, _amt0);
//             if (_actual1 != _amt1)
//                 revert Actual1DifferentExpected(_actual1, _amt1);
//         }

//         if (zeroForOne_) {
//             token0.safeIncreaseAllowance(router_, amountIn_);
//         } else {
//             token1.safeIncreaseAllowance(router_, amountIn_);
//         }

//         {
//             (bool success, ) = router_.call(payload_);
//             if (!success) revert SwapCallFailed();
//         }

//         // #endregion interactions.

//         // #region assertions.

//         uint256 balance0 = token0.balanceOf(address(this));
//         uint256 balance1 = token1.balanceOf(address(this));

//         if (zeroForOne_) {
//             if (_actual1 + expectedMinReturn_ > balance1)
//                 revert SlippageTooHigh();

            if (_actual0 - amountIn_ > balance0)
                revert RouterTakeTooMuchTokenIn();
        } else {
            if (_actual0 + expectedMinReturn_ > balance0)
                revert SlippageTooHigh();
            if (_actual1 - amountIn_ > balance1)
                revert RouterTakeTooMuchTokenIn();
        }

        // #endregion assertions.

        // #region deposit.

        token0.safeIncreaseAllowance(address(alm), balance0);
        token1.safeIncreaseAllowance(address(alm), balance1);

        alm.depositLiquidity(balance0, balance1, 0, 0);

        // #endregion deposit.

        // #region assertions.

        {
            uint256 newbalance0 = token0.balanceOf(address(this));
            uint256 newbalance1 = token1.balanceOf(address(this));

            if (newbalance0 > 0) revert NotDepositedAllToken0();

            if (newbalance1 > 0) revert NotDepositedAllToken1();
        }

        // #endregion assertions.

        emit LogSwap(_actual0, _actual1, balance0, balance1);
    }

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

    function setManager(address) external {
        revert NotImplemented();
    }

    function managerBalance0() external view returns (uint256 fees0) {
        (fees0, ) = pool.getPoolManagerFees();
    }

    function managerBalance1() external view returns (uint256 fees1) {
        (, fees1) = pool.getPoolManagerFees();
    }

    function managerFeePIPS() external view returns (uint256) {
        return pool.poolManagerFeeBips() * 1e2;
    }

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return (_init0, _init1);
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return alm.getReservesAtPrice(0);
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return alm.getReservesAtPrice(priceX96_);
    }

    // TODO: check if during any action we are validation that the valantis pool price
    // is near the oracle price??
    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// rebalance can happen.
    function validateRebalance(IOracleWrapper, uint24) external view {}

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

    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    // #endregion view functions.
}
