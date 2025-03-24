// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IArrakisPrivateHookFactory {
    // #region errors.

    error AddressZero();

    // #endregion errors.

    function createPrivateHook(
        address manager_,
        bytes32 salt_
    ) external returns (address hook);

    function addressOf(bytes32 salt_) external view returns (address);
}
