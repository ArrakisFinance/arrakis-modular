// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniswapV3Factory} from "./IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IVoter} from "./IVoter.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";
import {RebalanceParams} from "../structs/SUniswapV3.sol";

/// @title Velodrome Standard Private Module.
/// @author Arrakis Finance
/// @notice Velodrome Module interface, modules able to interact with velodrome dex. 
interface IVelodromeStandardModulePrivate {

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
    /// @dev triggered when new velo receiver is equal to old velo receiver.
    error SameReceiver();
    /// @dev triggered when pool has not been created on factory. 
    error PoolNotFound();
    /// @dev triggered when funded amounts are equals to zero.
    error AmountsZero();
    /// @dev triggered when caller is not the owner of the manager.
    error OnlyManagerOwner();
    /// @dev triggered when velo token is one of the token of the module token pair.
    error VELOTokenNotSupported();
    /// @dev triggered when gauge returned by voter is not alive.
    error GaugeKilled();

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

    /// @notice Event describing an claim by user of velo token.
    /// @param receiver the receiver of velo token.
    /// @param veloAmount the amount of velo token claimed.
    event LogClaim(
        address indexed receiver,
        uint256 veloAmount
    );

    /// @notice Event describing an claim by manager of velo token.
    /// @param receiver the receiver of velo token.
    /// @param veloAmount the amount of velo token claimed.
    event LogManagerClaim(
        address indexed receiver,
        uint256 veloAmount
    );

    /// @notice Event describing the update of receiver of manager velo reward.
    /// @param oldReceiver previous receiver of velo token.
    /// @param newReceiver new receiver of velo token.
    event LogSetReceiver(address oldReceiver, address newReceiver);

    // #endregion events.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the velodrome module.
    /// @param oracle_ oracle that will be the price reference.
    /// @param maxSlippage_ maximum slippage allowed during swap, mint and burn.
    /// @param veloReceiver_ recevier of velo token belonging to manager.
    /// @param tickSpacing_ tickSpacing of the velo pool to interact with.
    /// @param metaVault_ address of the meta vault
    function initialize(
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address veloReceiver_,
        int24 tickSpacing_,
        address metaVault_
    ) external;

    /// @notice function used to rebalance the inventory of the module.
    /// @param params_ params including decrease positions, swap, increase positions and mint datas.
    function rebalance(RebalanceParams calldata params_) external;

    /// @notice function used by user to claim the velo rewards.
    /// @param receiver_ address that will receive the velo rewards.
    function claimRewards(address receiver_) external;

    /// @notice function used by executor to claim the manager velo rewards.
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

    /// @notice function used to set the receiver of velo rewards.
    /// @param newReceiver_ new address that will receive the velo token.
    function setReceiver(
        address newReceiver_
    ) external;

    // #region view functions.
    /// @notice function used to get the NonFungiblePositionManager of velodrome.
    function nftPositionManager() external view returns (INonfungiblePositionManager);
    /// @notice function used to get the factory of velodrome.
    function factory() external view returns (IUniswapV3Factory);
    /// @notice function used to get the voter of velodrome.
    function voter() external view returns (IVoter);
    /// @notice function used to get the list of tokenIds of non fungible position.
    function tokenIds() external view returns (uint256[] memory);
    /// @notice function used to get the maximum slippage.
    function maxSlippage() external view returns (uint24);
    /// @notice function used to get velo token receiver.
    function veloReceiver() external view returns (address);
    /// @notice function used to get velo pool the module is interacting with.
    function pool() external view returns (address);
    /// @notice function used to get velo gauge associated to pool the module is interacting with.
    function gauge() external view returns (address);
    /// @notice function used to get velo balance due to manager.
    function veloManagerBalance() external view returns (uint256);
    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);
    // #endregion view functions.
    // #region constant.
    /// @notice function used to get velo token address.
    function VELO() external view returns (address);
    // #endregion constant.
}