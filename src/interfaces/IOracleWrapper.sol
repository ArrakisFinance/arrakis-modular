// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IOracleWrapper {
    // #region errors.

    error AddressZero();
    error DecimalsToken0Zero();
    error DecimalsToken1Zero();

    // #endregion errors.

    /// @notice function used to get price0.
    /// @return price0 price of token0/token1.
    function getPrice0() external view returns (uint256 price0);

    /// @notice function used to get price1.
    /// @return price1 price of token1/token0.
    function getPrice1() external view returns (uint256 price1);
}
