// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

interface IArrakisPrivateHook {
    // #region structs.

    struct SetFeesData {
        address module;
        uint24 zeroForOneFee;
        uint24 oneForZeroFee;
    }

    // #endregion structs.

    // #region errors.

    error AddressZero();
    error OnlyModule();
    error NotImplemented();
    error OnlyVaultExecutor();
    error ModuleNotSet();

    // #endregion errors.

    // #region events.

    event SetFees(
        PoolId indexed id,
        address indexed module,
        uint24 zeroForOneFee,
        uint24 oneForZeroFee
    );

    // #endregion events.

    function setFees(
        PoolKey calldata poolKey_,
        SetFeesData calldata data_
    ) external;

    // #region view functions.
    function manager() external view returns (address);
    function feesData(
        PoolId id_
    ) external view returns (address module, uint24 zeroForOneFee, uint24 oneForZeroFee);
    function zeroForOneFee(PoolId id_) external view returns (uint24);
    function oneForZeroFee(PoolId id_) external view returns (uint24);
    // #endregion view functions.

    // #region pure functions.

    function getHookPermissions()
        external
        pure
        returns (Hooks.Permissions memory);

    // #endregion pure functions.
}
