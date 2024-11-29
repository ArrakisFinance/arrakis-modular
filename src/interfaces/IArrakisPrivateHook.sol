// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

interface IArrakisPrivateHook {
    // #region errors.

    error AddressZero();
    error OnlyModule();
    error NotImplemented();
    error OnlyVaultExecutor();

    // #endregion errors.

    // #region events.

    event SetFees(uint24 zeroForOneFee, uint24 oneForZeroFee);

    // #endregion events.

    function setFees(
        uint24 zeroForOneFee_,
        uint24 oneForZeroFee_
    ) external;

    // #region view functions.

    function module() external view returns (address);
    function vault() external view returns (address);
    function manager() external view returns (address);
    function zeroForOneFee() external view returns (uint24);
    function oneForZeroFee() external view returns (uint24);

    // #endregion view functions.

    // #region pure functions.

    function getHookPermissions()
        external
        pure
        returns (Hooks.Permissions memory);

    // #endregion pure functions.
}
