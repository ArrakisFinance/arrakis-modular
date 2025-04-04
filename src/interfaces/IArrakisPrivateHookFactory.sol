// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IArrakisPrivateHookFactory {
    // #region errors.

    error AddressZero();

    // #endregion errors.

    // #region events.

    event LogCreatePrivateHook(
        address indexed hook,
        address indexed module,
        bytes32 salt
    );

    // #endregion events.

    function createPrivateHook(
        address module_,
        bytes32 salt_
    ) external returns (address hook);

    function addressOf(bytes32 salt_) external view returns (address);
}
