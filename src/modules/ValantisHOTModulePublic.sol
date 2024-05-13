// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisLPModulePublic} from
    "../interfaces/IArrakisLPModulePublic.sol";
import {IValantisHOTModulePublic} from
    "../interfaces/IValantisHOTModulePublic.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {ValantisModule} from "../abstracts/ValantisHOTModule.sol";
import {BASE, PIPS} from "../constants/CArrakis.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {IHOT} from "@valantis-hot/contracts/interfaces/IHOT.sol";

contract ValantisModulePublic is
    ValantisModule,
    IValantisHOTModulePublic,
    IArrakisLPModulePublic
{
    using SafeERC20 for IERC20Metadata;

    IOracleWrapper public oracle;
    bool public notFirstDeposit;

    constructor(address guardian_) ValantisModule(guardian_) {}

    // #region only vault owner.

    /// @notice set HOT, oracle (wrapper of HOT) and init manager fees function.
    /// @param alm_ address of the valantis HOT ALM.
    /// @param oracle_ address of the oracle used by the valantis HOT module.
    function setALMAndManagerFees(
        address alm_,
        address oracle_
    ) external {
        if (address(alm) != address(0)) {
            revert ALMAlreadySet();
        }
        if (msg.sender != IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }
        if (alm_ == address(0)) revert AddressZero();
        if (oracle_ == address(0)) revert AddressZero();

        alm = IHOT(alm_);
        oracle = IOracleWrapper(oracle_);
        pool.setPoolManagerFeeBips(_managerFeePIPS / 1e2);

        emit LogSetManagerFeePIPS(0, _managerFeePIPS);
        emit LogSetALM(alm_);
    }

    // #endregion only vault owner.

    /// @notice deposit function for public vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param proportion_ percentage of portfolio position vault want to expand.
    /// @return amount0 amount of token0 needed to expand the portfolio by "proportion"
    /// percent.
    /// @return amount1 amount of token1 needed to expand the portfolio by "proportion"
    /// percent.
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

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = pool.getReserves();

            if (!notFirstDeposit) {
                if (_amt0 > 0 || _amt1 > 0) {
                    // #region send dust on pool to manager.

                    address manager = metaVault.manager();

                    alm.withdrawLiquidity(_amt0, _amt1, manager, 0, 0);

                    // #endregion send dust on pool to manager.
                }

                _amt0 = _init0;
                _amt1 = _init1;
                notFirstDeposit = true;
            }

            amount0 =
                FullMath.mulDivRoundingUp(proportion_, _amt0, BASE);
            amount1 =
                FullMath.mulDivRoundingUp(proportion_, _amt1, BASE);
        }

        // #region get the tokens from the depositor.

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

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ number of share needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    ) public override returns (uint256 amount0, uint256 amount1) {
        if (proportion_ == BASE) {
            notFirstDeposit = false;
        }
        return super.withdraw(receiver_, proportion_);
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
            } else if (_amt1 < amountIn_) {
                revert NotEnoughToken1();
            }

            alm.withdrawLiquidity(_amt0, _amt1, address(this), 0, 0);

            _actual0 = token0.balanceOf(address(this)) - _initBalance0;
            _actual1 = token1.balanceOf(address(this)) - _initBalance1;
        }

        if (zeroForOne_) {
            token0.safeIncreaseAllowance(router_, amountIn_);
        } else {
            token1.safeIncreaseAllowance(router_, amountIn_);
        }

        {
            (bool success,) = router_.call(payload_);
            if (!success) revert SwapCallFailed();
        }

        // #endregion interactions.

        // #region assertions.

        uint256 balance0 =
            token0.balanceOf(address(this)) - _initBalance0;
        uint256 balance1 =
            token1.balanceOf(address(this)) - _initBalance1;

        if (zeroForOne_) {
            if (_actual1 + expectedMinReturn_ > balance1) {
                revert SlippageTooHigh();
            }
        } else {
            if (_actual0 + expectedMinReturn_ > balance0) {
                revert SlippageTooHigh();
            }
        }

        // #endregion assertions.

        // #region deposit.

        token0.safeIncreaseAllowance(address(alm), balance0);
        token1.safeIncreaseAllowance(address(alm), balance1);

        alm.depositLiquidity(
            balance0,
            balance1,
            expectedSqrtSpotPriceLowerX96_,
            expectedSqrtSpotPriceUpperX96_
        );

        // #endregion deposit.

        emit LogSwap(_actual0, _actual1, balance0, balance1);
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// @param oracle_ onchain oracle to check the current amm price against.
    /// @param maxDeviation_ maximum deviation tolerated by management.
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view override {
        uint256 oraclePrice = oracle_.getPrice0();
        uint8 decimals0 = token0.decimals();

        uint256 sqrtSpotPriceX96;
        (sqrtSpotPriceX96,,) = alm.getAMMState();

        uint256 currentPrice;

        if (sqrtSpotPriceX96 <= type(uint128).max) {
            currentPrice = FullMath.mulDiv(
                sqrtSpotPriceX96 * sqrtSpotPriceX96,
                10 ** decimals0,
                2 ** 192
            );
        } else {
            currentPrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    sqrtSpotPriceX96, sqrtSpotPriceX96, 1 << 64
                ),
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

        if (deviation > maxDeviation_) revert OverMaxDeviation();
    }

    // #region internal functions.

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
