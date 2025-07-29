// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IOracleWrapper} from "./IOracleWrapper.sol";
import {IPancakeDistributor} from "./IPancakeDistributor.sol";
import {Rebalance, Range, PositionLiquidity} from "../structs/SUniswapV3.sol";

interface IPancakeSwapV3StandardModule {
    // #region errors.

    error OnlyMetaVaultOwner();
    error MaxSlippageGtTenPercent();
    error AmountZero();
    error InsufficientFunds();
    error LengthsNotEqual();
    error SamePool();
    error MintToken0();
    error MintToken1();
    error BurnToken0();
    error BurnToken1();
    error OverMaxDeviation();
    error NativeCoinNotSupported();
    error PoolNotFound();
    error ExpectedMinReturnTooLow();
    error WrongRouter();
    error SlippageTooHigh();
    error OnlyPool();
    error ClaimParamsLengthZero();
    error OnlyManagerOwner();
    error SameReceiver();

    // #endregion errors.

    // #region events.

    event LogApproval(
        address indexed spender, address[] tokens, uint256[] amounts
    );
    event LogRebalance(
        PositionLiquidity[] burns,
        PositionLiquidity[] mints,
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
    event LogSetPool(
        address oldPool,
        address pool,
        Rebalance rebalance
    );
    event LogSetReceiver(
        address oldReceiver,
        address newReceiver
    );
    event LogClaimManagerReward(
        address indexed token,
        uint256 amount
    );
    event LogClaimReward(
        address indexed token,
        uint256 amount
    );

    // #endregion events.

    function initialize(
        uint256 init0_,
        uint256 init1_,
        uint24 fee_,
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address rewardReceiver_,
        address metaVault_
    ) external;

    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts
    ) external;

    function setPool(
        uint24 fee_,
        Rebalance calldata rebalance_
    ) external;

    function rebalance(
        Rebalance calldata rebalance_
    ) external;

    function pancakeV3MintCallback(
        uint256 amount0Owed,
        uint256 amount1Owed,
        bytes calldata data
    ) external;

    function setReceiver(
        address newReceiver_
    ) external;

    function claimManagerRewards(
        IPancakeDistributor.ClaimParams[] calldata params_
    ) external;

    function claimRewards(
        IPancakeDistributor.ClaimParams[] calldata params_,
        address receiver_
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

    function rewardReceiver() external view returns (address);

    // #endregion view functions.
}
