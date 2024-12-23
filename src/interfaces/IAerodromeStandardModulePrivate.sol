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
    error OverBurn();
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

    // #endregion errors.

    // #region events.

    event LogDeposit(
        address indexed depositor,
        uint256 amount0In,
        uint256 amount1In
    );

    event LogWithdraw(
        address indexed receiver,
        uint256 amount0Out,
        uint256 amount1Out
    );

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

    // #region view functions.

    function nftPositionManager() external view returns (INonfungiblePositionManager);
    function factory() external view returns (IUniswapV3Factory);
    function tokenIds() external view returns (uint256[] memory);

    // #endregion view functions.
}