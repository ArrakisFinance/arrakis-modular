// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IArrakisMetaOwned {
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
}