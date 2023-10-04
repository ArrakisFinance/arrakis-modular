// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IOracleWrapper} from "./IOracleWrapper.sol";

interface ISwap {
    // #region events.

    event LogSwap(address target_, bytes data_, int256 amount0, int256 amount1);

    // #endregion events.

    /// @notice function used by metaVault to convert token0 into token1
    /// or token1 into token0.
    /// @param target_ smart contract to call to do the swap.
    /// @param data_ payload which will perform the swap.
    function swap(address target_, bytes calldata data_) external;

    // #region view external functions.

    /// @notice function used to get the oracle of the token pair.
    /// @return oracle price feed to get a reliable price.
    function oracle() external view returns (IOracleWrapper oracle);

    // #endregion view external functions.
}
