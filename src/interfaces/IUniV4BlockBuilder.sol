// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IUniV4BlockBuilder {
    // #region errors.

    // #endregion errors.

    // #region state modifying functions.

    // #endregion state modifying functions.

    // #region view functions.

    /// @dev view function to get amounts of token0/token1 inside ranges as liquidity.
    function getAmountsAndFees()
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fees0,
            uint256 fees1
        );

    // #endregion view functions.
}
