// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IValantisModule} from "../interfaces/IValantisSOTModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {ISovereignPool} from "../interfaces/ISovereignPool.sol";
import {ISovereignALM} from "../interfaces/ISovereignALM.sol";
import {IDecimals} from "../interfaces/IDecimals.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {PIPS} from "../constants/CArrakis.sol";

contract ValantisModule is IArrakisLPModule, IValantisModule, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // #region public immutable properties.

    IArrakisMetaVault public immutable metaVault;
    ISovereignPool public immutable pool;
    ISovereignALM public immutable alm;
    IERC20 public immutable token0;
    IERC20 public immutable token1;
    /// @dev should we change it to mutable state variable,
    /// and settable by who?
    uint24 public immutable maxSlippage;

    // #endregion public immutable properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault))
            revert OnlyMetaVault(msg.sender, address(metaVault));
        _;
    }

    // #endregion modifiers.

    constructor(
        address metaVault_,
        address pool_,
        address alm_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_
    ) {
        if (metaVault_ == address(0)) revert AddressZero();
        if (pool_ == address(0)) revert AddressZero();
        if (alm_ == address(0)) revert AddressZero();
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
        if (maxSlippage_ > PIPS / 10) revert MaxSlippageGtTenPercent();

        metaVault = IArrakisMetaVault(metaVault_);
        pool = ISovereignPool(pool_);
        alm = ISovereignALM(alm_);

        token0 = IERC20(metaVault.token0());
        token1 = IERC20(metaVault.token1());

        _init0 = init0_;
        _init1 = init1_;

        maxSlippage = maxSlippage_;
    }

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
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = alm.getReserves();

            if (_amt0 == 0 && _amt1 == 0) {
                _amt0 = _init0;
                _amt1 = _init1;
            }

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        uint256 _liq;
        {
            uint256 totalSupply = alm.totalSupply();
            totalSupply = totalSupply == 0 ? 1e18 : totalSupply;

            _liq = FullMath.mulDiv(proportion_, totalSupply, PIPS);
        }

        // #endregion effects.

        // #region interactions.

        // #region get the tokens from the depositor.

        token0.safeTransferFrom(depositor_, address(this), amount0);
        token1.safeTransferFrom(depositor_, address(this), amount1);

        // #endregion get the tokens from the depositor.

        // #region increase allowance to alm.

        token0.safeIncreaseAllowance(address(alm), amount0);
        token1.safeIncreaseAllowance(address(alm), amount1);

        // #endregion increase allowance to alm.

        alm.depositLiquidity(
            amount0,
            amount1,
            block.timestamp,
            _liq,
            address(this),
            ""
        );

        // #endregion interactions.

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

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
        if (proportion_ > PIPS) revert CannotBurnMtTotalSupply();

        uint256 _liq;
        {
            uint256 totalSupply = alm.totalSupply();
            if (totalSupply == 0) revert TotalSupplyZero();

            _liq = FullMath.mulDiv(proportion_, totalSupply, PIPS);
        }

        // #endregion checks.

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = alm.getReserves();

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        // #endregion effects.

        // #region interactions.

        (uint256 actual0, uint256 actual1) = alm.withdrawLiquidity(
            _liq,
            amount0,
            amount1,
            block.timestamp,
            receiver_,
            ""
        );

        // #endregion interactions.

        // #region assertions.

        if (actual0 != amount0)
            revert Actual0DifferentExpected(actual0, amount0);
        if (actual1 != amount1)
            revert Actual1DifferentExpected(actual1, amount1);

        // #endregion assertions.

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    function withdrawManagerBalance()
        external
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

    function setManagerFeePIPS(uint256 newFeePIPS_) external {
        uint256 _oldFee = pool.poolManagerFeeBips();

        // #region checks.

        if (msg.sender != metaVault.manager())
            revert OnlyManager(msg.sender, metaVault.manager());

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        pool.setPoolManagerFeeBips(newFeePIPS_ / 1e2);

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_ / 1e2);
    }

    function swap(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        uint256 newLiquidity_,
        address router_,
        bytes calldata payload_
    ) external {
        // #region checks/effects.

        // check only manager can call this function.
        {
            address manager = metaVault.manager();
            if (manager != msg.sender) revert OnlyManager(msg.sender, manager);
        }

        _checkMinReturn(
            zeroForOne_,
            expectedMinReturn_,
            amountIn_,
            maxSlippage,
            IDecimals(address(token0)).decimals(),
            IDecimals(address(token1)).decimals()
        );

        uint256 _liq = alm.totalSupply();
        if (_liq == 0) revert TotalSupplyZero();

        // #endregion checks/effects.

        // #region interactions.

        uint256 _amt0;
        uint256 _amt1;
        uint256 actual0;
        uint256 actual1;

        {
            (_amt0, _amt1) = alm.getReserves();

            if (zeroForOne_) {
                if (_amt0 < amountIn_) revert NotEnoughToken0();
            } else if (_amt1 < amountIn_) revert NotEnoughToken1();

            (actual0, actual1) = alm.withdrawLiquidity(
                _liq,
                _amt0,
                _amt1,
                block.timestamp,
                address(this),
                ""
            );

            if (actual0 != _amt0)
                revert Actual0DifferentExpected(actual0, _amt0);
            if (actual1 != _amt1)
                revert Actual1DifferentExpected(actual1, _amt1);
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
            if (actual1 + expectedMinReturn_ > balance1)
                revert SlippageTooHigh();

            if (actual0 - amountIn_ > balance0)
                revert RouterTakeTooMuchTokenIn();
        } else {
            if (actual0 + expectedMinReturn_ > balance0)
                revert SlippageTooHigh();
            if (actual1 - amountIn_ > balance1)
                revert RouterTakeTooMuchTokenIn();
        }

        // #endregion assertions.

        // #region deposit.

        token0.safeIncreaseAllowance(address(alm), balance0);
        token1.safeIncreaseAllowance(address(alm), balance1);

        alm.depositLiquidity(
            balance0,
            balance1,
            block.timestamp,
            newLiquidity_,
            address(this),
            ""
        );

        // #endregion deposit.

        // #region assertions.

        {
            uint256 newbalance0 = token0.balanceOf(address(this));
            uint256 newbalance1 = token1.balanceOf(address(this));

            if (newbalance0 > 0) revert NotDepositedAllToken0();

            if (newbalance1 > 0) revert NotDepositedAllToken1();
        }

        // #endregion assertions.

        emit LogSwap(actual0, actual1, balance0, balance1);
    }

    function setManager(address newManager_) external {
        revert NotImplemented();
    }

    function managerBalance0() external view returns (uint256) {
        return pool.feePoolManager0();
    }

    function managerBalance1() external view returns (uint256) {
        return pool.feePoolManager1();
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
        return alm.getReserves();
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return alm.getReservesAtPrice(priceX96_);
    }

    // #region view functions.

    function _getPrice0(
        uint8 decimals0_
    ) internal view returns (uint256 price0) {
        uint256 priceX96 = alm.getSqrtOraclePriceX96();

        if (priceX96 <= type(uint128).max) {
            price0 = FullMath.mulDiv(
                priceX96 * priceX96,
                10 ** decimals0_,
                2 ** 192
            );
        } else {
            price0 = FullMath.mulDiv(
                FullMath.mulDiv(priceX96, priceX96, 1 << 64),
                10 ** decimals0_,
                1 << 128
            );
        }
    }

    function _getPrice1(
        uint8 decimals1_
    ) internal view returns (uint256 price1) {
        uint256 priceX96 = alm.getSqrtOraclePriceX96();

        if (priceX96 <= type(uint128).max) {
            price1 = FullMath.mulDiv(
                2 ** 192,
                10 ** decimals1_,
                priceX96 * priceX96
            );
        } else {
            price1 = FullMath.mulDiv(
                1 << 128,
                10 ** decimals1_,
                FullMath.mulDiv(priceX96, priceX96, 1 << 64)
            );
        }
    }

    function _checkMinReturn(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        uint24 maxSlippage_,
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
                FullMath.mulDiv(
                    _getPrice0(decimals0_),
                    PIPS - maxSlippage,
                    PIPS
                )
            ) revert ExpectedMinReturnTooLow();
        } else {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_,
                    10 ** decimals1_,
                    amountIn_
                ) <
                FullMath.mulDiv(
                    _getPrice1(decimals1_),
                    PIPS - maxSlippage,
                    PIPS
                )
            ) revert ExpectedMinReturnTooLow();
        }
    }

    // #endregion view functions.
}
