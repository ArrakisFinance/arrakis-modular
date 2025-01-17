// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Factory} from "./IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IVoter} from "./IVoter.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";
import {RebalanceParams} from "../structs/SUniswapV3.sol";

/// @title Aerodrome Standard Private Module.
/// @author Arrakis Finance
/// @notice Aerodrome Module interface, modules able to interact with aerodrome dex. 
interface IAerodromeStandardModulePrivate {

    // #region errors.

    /// @dev triggered when the max slippage variable is set to greater than 10%.
    error MaxSlippageGtTenPercent();
    /// @dev triggered when the caller is different than the meta vault owner.
    error OnlyMetaVaultOwner();
    /// @dev triggered when token pair contain native coin.
    error NativeCoinNotSupported();
    /// @dev triggered when burn of token0 is smaller than expected.
    error BurnToken0();
    /// @dev triggered when burn of token1 is smaller than expected.
    error BurnToken1();
    /// @dev triggered when mint of token0 is smaller than expected.
    error MintToken0();
    /// @dev triggered when mint of token1 is smaller than expected.
    error MintToken1();
    /// @dev triggered when tokenId of position is unknown from the module.
    error TokenIdNotFound();
    /// @dev triggered when token0 of mintParams is different than module token0.
    error Token0Mismatch();
    /// @dev triggered when token1 of mintParams is different than module token1.
    error Token1Mismatch();
    /// @dev triggered when tick spacing of mintParams is different than the pool module.
    error TickSpacingMismatch();
    /// @dev triggered when min return of rebalance swap is too low.
    error ExpectedMinReturnTooLow();
    /// @dev triggered when swap router of the rebalance payload is unauthorized address.
    error WrongRouter();
    /// @dev triggered when amount received from rebalance swap is too low.
    error SlippageTooHigh();
    /// @dev triggered when deviation of pool price from oracle price is
    /// greater than max allowed value.
    error OverMaxDeviation();
    /// @dev triggered when new aero receiver is equal to old aero receiver.
    error SameReceiver();
    /// @dev triggered when pool has not been created on factory. 
    error PoolNotFound();
    /// @dev triggered when funded amounts are equals to zero.
    error AmountsZero();
    error OnlyManagerOwner();

    // #endregion errors.

    // #region events.

    /// @notice Event describing an approval of left overs to an address.
    /// @param spender the address that will get the allowance.
    /// @param amount0 the amount of token0 allowed to spender.
    /// @param amount1 the amount of token1 allowed to spender.
    event LogApproval(
        address indexed spender,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Event describing an rebalance results on underlying.
    /// @param burn0 the amount of token0 burned during rebalance.
    /// @param burn1 the amount of token1 burned during rebalance.
    /// @param mint0 the amount of token0 minted during rebalance.
    /// @param mint1 the amount of token1 minted during rebalance.
    event LogRebalance(
        uint256 burn0,
        uint256 burn1,
        uint256 mint0,
        uint256 mint1
    );

    /// @notice Event describing an claim by user of aero token.
    /// @param receiver the receiver of aero token.
    /// @param aeroAmount the amount of aero token claimed.
    event LogClaim(
        address indexed receiver,
        uint256 aeroAmount
    );

    /// @notice Event describing an claim by manager of aero token.
    /// @param receiver the receiver of aero token.
    /// @param aeroAmount the amount of aero token claimed.
    event LogManagerClaim(
        address indexed receiver,
        uint256 aeroAmount
    );

    /// @notice Event describing the update of receiver of manager aero reward.
    /// @param oldReceiver previous receiver of aero token.
    /// @param newReceiver new receiver of aero token.
    event LogSetReceiver(address oldReceiver, address newReceiver);

    // #endregion events.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the aerodrome module.
    /// @param oracle_ oracle that will be the price reference.
    /// @param maxSlippage_ maximum slippage allowed during swap, mint and burn.
    /// @param aeroReceiver_ recevier of aero token belonging to manager.
    /// @param tickSpacing_ tickSpacing of the aero pool to interact with.
    /// @param metaVault_ address of the meta vault
    function initialize(
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address aeroReceiver_,
        int24 tickSpacing_,
        address metaVault_
    ) external;

    /// @notice function used to rebalance the inventory of the module.
    /// @param params_ params including decrease positions, swap, increase positions and mint datas.
    function rebalance(RebalanceParams calldata params_) external;

    /// @notice function used by user to claim the aero rewards.
    /// @param receiver_ address that will receive the aero rewards.
    function claimRewards(address receiver_) external;

    /// @notice function used by executor to claim the manager aero rewards.
    function claimManager() external;

    /// @notice function used to approve a spender to use the left over of the module.
    /// @param spender_ address that will be allowed to use left over.
    /// @param amount0_ amount of token0 allowed to be used by spender.
    /// @param amount1_ amount of token1 allowed to be used by spender.
    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external;

    /// @notice function used to set the receiver of aero rewards.
    /// @param newReceiver_ new address that will receive the aero token.
    function setReceiver(
        address newReceiver_
    ) external;

    // #region view functions.
    /// @notice function used to get the NonFungiblePositionManager of aerodrome.
    function nftPositionManager() external view returns (INonfungiblePositionManager);
    /// @notice function used to get the factory of aerodrome.
    function factory() external view returns (IUniswapV3Factory);
    /// @notice function used to get the voter of aerodrome.
    function voter() external view returns (IVoter);
    /// @notice function used to get the list of tokenIds of non fungible position.
    function tokenIds() external view returns (uint256[] memory);
    /// @notice function used to get the maximum slippage.
    function maxSlippage() external view returns (uint24);
    /// @notice function used to get aero token receiver.
    function aeroReceiver() external view returns (address);
    /// @notice function used to get aero pool the module is interacting with.
    function pool() external view returns (address);
    /// @notice function used to get aero gauge associated to pool the module is interacting with.
    function gauge() external view returns (address);
    /// @notice function used to get aero balance due to manager.
    function aeroManagerBalance() external view returns (uint256);
    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);
    // #endregion view functions.
    // #region constant.
    /// @notice function used to get aero token address.
    function AERO() external view returns (address);
    // #endregion constant.
}