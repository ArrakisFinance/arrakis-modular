// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {ISovereignPool} from "./ISovereignPool.sol";
import {ISOT} from "@valantis-sot/contracts/interfaces/ISOT.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

interface IValantisSOTModule {
    // #region errors.

    /// @notice
    error NoNativeToken();
    error OnlyPool(address caller, address pool);
    error AmountsZeros();
    error NotImplemented();
    error ExpectedMinReturnTooLow();
    error MaxSlippageGtTenPercent();
    error NotDepositedAllToken0();
    error NotDepositedAllToken1();
    error OnlyMetaVaultOwner();
    error ALMAlreadySet();

    // #endregion errors.

    // #region events.

    event LogSetALM(address alm);
    event LogInitializePosition(uint256 amount0, uint256 amount1);

    // #endregion events.

    // #region state modifying functions.

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
    ) external;

    /// @notice initialize position, needed when vault owner active this module.
    function initializePosition() external;

    /// @notice fucntion used to set range on valantis AMM
    /// @param _sqrtPriceLowX96 lower bound of the range in sqrt price.
    /// @param _sqrtPriceHighX96 upper bound of the range in sqrt price.

    /// @param _expectedSqrtSpotPriceLowerX96 expected upper limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    /// @param _expectedSqrtSpotPriceUpperX96 expected lower limit of current spot
    /// price (to prevent sandwich attack and manipulation).
    function setPriceBounds(
        uint160 _sqrtPriceLowX96,
        uint160 _sqrtPriceHighX96,
        uint160 _expectedSqrtSpotPriceLowerX96,
        uint160 _expectedSqrtSpotPriceUpperX96
    ) external;

    // #endregion state modifiying functions.

    // #region view functions.

    /// @notice function used to get the valantis sot pool.
    function pool() external view returns (ISovereignPool);

    /// @notice function used to get the valantis sot alm/ liquidity module.
    function alm() external view returns (ISOT);

    /// @notice function used to get the max slippage that
    /// can occur during swap rebalance.
    function maxSlippage() external view returns (uint24);

    // #endregion view functions.
}
