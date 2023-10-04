// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IOracleWrapper {
    /// @notice function used to get price of one token0 in token1 term.
    /// @return price0 token0/token1 price.
    function getPrice0() external view returns (uint256 price0);

    /// @notice function used to get price of one token1 in token0 term.
    /// @return price1 token1/token0 price.
    function getPrice1() external view returns (uint256 price1);
}