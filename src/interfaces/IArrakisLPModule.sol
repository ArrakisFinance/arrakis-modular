// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {IArrakisMetaVault} from "./IArrakisMetaVault.sol";

interface IArrakisLPModule {
    // #region events.

    event LogDeposit(uint256 proportion, uint256 amount0, uint256 amount1);
    event LogWithdraw(uint256 proportion, uint256 amount0, uint256 amount1);

    // #endregion events.

    /// @notice function used by metaVault to deposit tokens into the strategy.
    /// @param proportion_ number of share needed to be add.
    /// @return amount0 amount of token0 deposited.
    /// @return amount1 amount of token1 deposited.
    function deposit(
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param proportion_ number of share needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get token0 as IERC20.
    function token0() external view returns (IERC20);

    /// @notice function used to get token0 as IERC20.
    function token1() external view returns (IERC20);

    /// @notice function used to get metaVault as IArrakisMetaVault.
    function metaVault() external view returns (IArrakisMetaVault);

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits() external view returns (uint256 init0, uint256 init1);

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
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1);
}
