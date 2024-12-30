// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Factory} from "./IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";
import {Range, RebalanceParams} from "../structs/SUniswapV3.sol";

interface IAerodromeStandardModulePrivate {

    // #region errors.

    error MaxSlippageGtTenPercent();
    error OnlyMetaVaultOwner();
    error NativeCoinNotSupported();
    error CallbackNotAuthorized();
    error BurnToken0();
    error BurnToken1();
    error MintToken0();
    error MintToken1();
    error TokenIdNotFound();
    error Token0Mismatch();
    error Token1Mismatch();
    error ExpectedMinReturnTooLow();
    error WrongRouter();
    error SlippageTooHigh();
    error OverMaxDeviation();
    error SameReceiver();
    error TickSpacingMismatch();
    error PoolNotFound();
    error AmountsZero();

    // #endregion errors.

    // #region events.
    event LogApproval(
        address indexed spender,
        uint256 amount0,
        uint256 amount1
    );

    event LogRebalance(
        uint256 burn0,
        uint256 burn1,
        uint256 mint0,
        uint256 mint1
    );

    event LogClaim(
        address indexed receiver,
        uint256 aeroAmount
    );

    event LogManagerClaim(
        address indexed receiver,
        uint256 aeroAmount
    );

    event LogSetReceiver(address oldReceiver, address newReceiver);

    // #endregion events.

    function initialize(
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address aeroReceiver_,
        int24 tickSpacing_,
        address metaVault_
    ) external;
    function rebalance(RebalanceParams calldata params_) external;
    function claimRewards(address receiver_) external;
    function claimManager() external;
    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external;
    function setReceiver(
        address newReceiver_
    ) external;

    // #region view functions.
    function nftPositionManager() external view returns (INonfungiblePositionManager);
    function factory() external view returns (IUniswapV3Factory);
    function tokenIds() external view returns (uint256[] memory);
    function maxSlippage() external view returns (uint24);
    function aeroReceiver() external view returns (address);
    function pool() external view returns (address);
    function aeroManagerBalance() external view returns (uint256);
    // #endregion view functions.
}