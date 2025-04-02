// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUniV4Oracle {
    // #region errors.

    error SqrtPriceZero();

    // #endregion errors.

    function initialize(
        address module_
    ) external;

    // #region view functions.

    function module() external view returns (address);
    function poolManager() external view returns (address);
    function decimals0() external view returns (uint8);
    function decimals1() external view returns (uint8);
    function isInversed() external view returns (bool);

    // #endregion view functions.
}
