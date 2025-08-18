// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IOracleWrapper} from "./IOracleWrapper.sol";
import {RebalanceParams} from "../structs/SPancakeSwapV3.sol";

interface IPancakeSwapV3StandardModule {
    // #region errors.

    error MaxSlippageGtTenPercent();
    error PoolNotFound();
    error OnlyMetaVaultOwner();
    error ExpectedMinReturnTooLow();
    error FeeMismatch();
    error Token0Mismatch();
    error Token1Mismatch();
    error OverMaxDeviation();
    error WrongRouter();
    error SlippageTooHigh();
    error MintToken1();
    error MintToken0();
    error TokenIdNotFound();
    error OnlyManagerOwner();
    error SameReceiver();
    error NativeCoinNotAllowed();
    error LengthsNotEqual();
    error BurnToken0();
    error BurnToken1();

    // #endregion errors.

    // #region events.

    /// @notice Event describing an approval of left overs to an address.
    /// @param spender the address that will get the allowance.
    /// @param tokens the tokens that will be allowed to spender.
    /// @param amounts the amount of tokens that will be allowed to spender.
    event LogApproval(
         address indexed spender, address[] tokens, uint256[] amounts
    );

    /// @notice Event describing an rebalance results on underlying.
    /// @param burn0 the amount of token0 burned during rebalance.
    /// @param burn1 the amount of token1 burned during rebalance.
    /// @param mint0 the amount of token0 minted during rebalance.
    /// @param mint1 the amount of token1 minted during rebalance.
    event LogRebalance(
        uint256 burn0, uint256 burn1, uint256 mint0, uint256 mint1
    );

    /// @notice Event describing an claim by user of aero token.
    /// @param receiver the receiver of aero token.
    /// @param aeroAmount the amount of aero token claimed.
    event LogClaim(address indexed receiver, uint256 aeroAmount);

    /// @notice Event describing an claim by manager of aero token.
    /// @param receiver the receiver of aero token.
    /// @param aeroAmount the amount of aero token claimed.
    event LogManagerClaim(
        address indexed receiver, uint256 aeroAmount
    );

    /// @notice Event describing the update of receiver of manager aero reward.
    /// @param oldReceiver previous receiver of aero token.
    /// @param newReceiver new receiver of aero token.
    event LogSetReceiver(address oldReceiver, address newReceiver);

    // #endregion events.

    // #region functions.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the pancake v3 module.
    /// @param oracle_ oracle that will be the price reference.
    /// @param maxSlippage_ maximum slippage allowed during swap, mint and burn.
    /// @param cakeReceiver_ recevier of cake token belonging to manager.
    /// @param fee_ fee of the pancake v3 pool to interact with.
    /// @param metaVault_ address of the meta vault
    function initialize(
        IOracleWrapper oracle_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_,
        address cakeReceiver_,
        uint24 fee_,
        address metaVault_
    ) external;

    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts
    ) external;

    /// @notice function used to rebalance the inventory of the module.
    /// @param params_ parameters of the rebalance.
    function rebalance(RebalanceParams calldata params_) external;

    /// @notice function used by user to claim the cake rewards.
    /// @param receiver_ address that will receive the cake rewards.
    function claimRewards(
        address receiver_
    ) external;

    /// @notice function used by executor to claim the manager cake rewards.
    function claimManager() external;

    /// @notice function used to set the receiver of cake rewards.
    /// @param newReceiver_ new address that will receive the cake token.
    function setReceiver(
        address newReceiver_
    ) external;

    // #endregion functions.

    // #region view functions.

    /// @notice function used to get the list of tokenIds of non fungible position.
    function tokenIds() external view returns (uint256[] memory);
    /// @notice function used to get the maximum slippage.
    function maxSlippage() external view returns (uint24);
    /// @notice function used to get cake token receiver.
    function cakeReceiver() external view returns (address);
    /// @notice function used to get aero pool the module is interacting with.
    function pool() external view returns (address);
    /// @notice function used to get cake balance due to manager.
    function cakeManagerBalance() external view returns (uint256);
    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);

    // #endregion view functions.

    // #region constant/immutable.

    /// @notice function used to get the NonFungiblePositionManager of pancake swap v3.
    function nftPositionManager() external view returns (address);
    /// @notice function used to get the factory of pancake swap v3.
    function factory() external view returns (address);
    /// @notice function used to get cake token address.
    function CAKE() external view returns (address);
    /// @notice function used to get the masterchef of pancake swap v3.
    function masterChefV3() external view returns (address);

    // #endregion constant/immutable.
}
