// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

interface IPermissionHook {
    // #region errors.

    error AddressZero();
    error OnlyModule();
    error NotImplemented();

    // #endregion errors.

    // #region view functions.

    function module() external view returns (address);

    // #endregion view functions.
}
