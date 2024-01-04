// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignPool} from "./ISovereignPool.sol";
import {ISOT} from "./ISOT.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

interface IValantisSOTModule {
    // #region errors.

    /// @notice 
    error NoNativeToken();
    error OnlyPool(address caller, address pool);
    error TotalSupplyZero();
    error Actual0DifferentExpected(uint256 actual0, uint256 expected0);
    error Actual1DifferentExpected(uint256 actual1, uint256 expected1);
    error NotImplemented();
    error ExpectedMinReturnTooLow();
    error MaxSlippageGtTenPercent();
    error NotEnoughToken0();
    error NotEnoughToken1();
    error SwapCallFailed();
    error SlippageTooHigh();
    error RouterTakeTooMuchTokenIn();
    error NotDepositedAllToken0();
    error NotDepositedAllToken1();

    // #endregion errors.

    // #region events.

    event LogSwap(
        uint256 oldBalance0,
        uint256 oldBalance1,
        uint256 newBalance0,
        uint256 newBalance1
    );

    // #endregion events.

    // #region state modifying functions.

    /// @notice function used to set new manager
    /// @dev setting a manager different than the module,
    /// will make the module unusable.
    /// let's make it not implemented for now
    function setManager(address newManager_) external;

    /// @notice fucntion used to set range on valantis AMM
    /// @param _sqrtPriceLowX96 lower bound of the range in sqrt price.
    /// @param _sqrtPriceHighX96 upper bound of the range in sqrt price.
    /// @param _expectedSqrtSpotPriceUpperX96 expected lower limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    /// @param _expectedSqrtSpotPriceLowerX96 expected upper limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    function setPriceBounds(
        uint128 _sqrtPriceLowX96,
        uint128 _sqrtPriceHighX96,
        uint160 _expectedSqrtSpotPriceUpperX96,
        uint160 _expectedSqrtSpotPriceLowerX96
    ) external;

    // #endregion state modifiying functions.

    // #region view functions.

    /// @notice function used to get the valantis sot pool.
    function pool() external view returns (ISovereignPool);

    /// @notice function used to get the valantis sot alm/ liquidity module.
    function alm() external view returns (ISOT);

    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);

    /// @notice function used to get the max slippage that
    /// can occur during swap rebalance. 
    function maxSlippage() external view returns (uint24);

    // #endregion view functions.
}
