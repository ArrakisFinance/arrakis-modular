// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisLPModuleVault} from "./IArrakisLPModuleVault.sol";

/// @title IArrakisMetaVault
/// @notice IArrakisMetaVault is a vault that is able to invest dynamically deposited
/// tokens into protocols through his module.
interface IArrakisMetaVault {
    // #region errors.

    error AddressZero();

    // #endregion errors.

    // #region events.

    event LogDeposit(uint256 proportion, uint256 amount0, uint256 amount1);
    event LogWithdraw(
        uint256 proportion,
        address receiver,
        uint256 amount0,
        uint256 amount1
    );
    event LogRebalance(bytes[] payloads);
    event LogModuleCallback(address module, uint256 amount0, uint256 amount1);
    event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
    event LogSetManager(address oldManager, address newManager);
    /// @dev storing manager fee on the contract will make it possible to
    /// change fee pips without retroactively applying new feePIPS to old
    /// fee earned.
    event LogSetManagerFeePIPS(
        uint24 oldManagerFeePIPS,
        uint24 newManagerFeePIPS
    );

    // #endregion events.

    /// @notice function used to deposit tokens or expand position inside the
    /// inherent strategy.
    /// @param proportion_ the proportion of position expansion.
    /// @return amount0 amount of token0 need to increase the position by proportion_;
    /// @return amount1 amount of token1 need to increase the position by proportion_;
    function deposit(uint256 proportion_) external returns(uint256 amount0, uint256 amount1);

    /// @notice function used to withdraw tokens or position contraction of the
    /// underpin strategy.
    /// @param proportion_ the proportion of position contraction.
    /// @param receiver_ the address that will receive withdrawn tokens.
    /// @return amount0 amount of token0 returned.
    /// @return amount1 amount of token1 returned.
    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used by manager to change the strategy
    /// @param payloads_ datas to use when calling module to rebalance the position.
    function rebalance(bytes[] calldata payloads_) external;

    /// @notice function used by module to get tokens 
    function moduleCallback(uint256 amount0, uint256 amount1) external;

    /// @notice function used by manager to withdraw fees
    function withdrawManagerBalance() external returns (uint256 amount0, uint256 amount1);

    /// @notice function used by owner to set the Manager
    /// responsible to rebalance the position.
    /// @param newManager_ address of the new manager.
    function setManager(address newManager_) external;

    /// @notice function used by manager to set the cut he will
    /// take from APY generated from the position managed.
    /// @dev value should be lower than 1 PIPS = 100_000
    /// @param managerFeePIP_ the percentage of cut the manager will take.
    function setManagerFeePIPS(uint24 managerFeePIP_) external;

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96 price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint256 priceX96
    ) external view returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits() external view returns (uint256 init0, uint256 init1);

    /// @notice function used to get the address of token0.
    function token0() external view returns (address);

    /// @notice function used to get the address of token1.
    function token1() external view returns (address);

    /// @notice function used to get manager address.
    function manager() external view returns (address);

    /// @notice function used to get manager Fees in PIPS.
    function managerFeePIPS() external returns (uint24);

    /// @notice function used to get manager balance in token0
    /// that can be withdrawn by manager.
    function managerBalance0() external returns (uint256);

    /// @notice function used to get manager balance in token1
    /// that can be withdrawn by manager.
    function managerBalance1() external returns (uint256);

    /// @notice function used to get module used to 
    /// open/close/manager a position.
    function module() external view returns (IArrakisLPModuleVault);

    /// @notice function used to get the duration btw 2 manager fee update.
    function feeDuration() external view returns(uint256);

    /// @notice function to get the timestamp of the last manager fee update.
    function lastFeeUpdate() external view returns(uint256);
}
