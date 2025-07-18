// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IOracleWrapper} from "./IOracleWrapper.sol";
import {Rebalance, Range} from "../structs/SUniswapV3.sol";

interface IPancakeSwapV3StandardModule {
    // #region errors.

    error OnlyMetaVaultOwner();
    error MaxSlippageGtTenPercent();
    error SqrtPriceZero();
    error AmountZero();
    error InsufficientFunds();
    error LengthsNotEqual();
    error SamePool();
    error MintToken0();
    error MintToken1();
    error BurnToken0();
    error BurnToken1();
    error OverMaxDeviation();

    // #endregion errors.

    // #region events.

    // #endregion events.

    function initialize(
        uint256 init0_,
        uint256 init1_,
        address pool_,
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address metaVault_
    ) external;

    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts
    ) external;

    function setPool(
        address pool_
    ) external;

    function rebalance(
        Rebalance calldata rebalance_
    ) external;

    /// @notice function used to withdraw eth from the module.
    /// @dev these fund will be used to swap eth to the other token
    /// of the currencyPair to rebalance the inventory inside a single tx.
    function withdrawEth(
        uint256 amount_
    ) external;

    function uniswapV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;

    // #region view functions.

    function pool() external view returns (address);

    function oracle() external view returns (IOracleWrapper);

    function maxSlippage() external view returns (uint24);

    /// @notice function used to get the list of active ranges.
    /// @return ranges active ranges
    function getRanges()
        external
        view
        returns (Range[] memory ranges);

    // #endregion view functions.
}
