// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

interface IArrakisPrivateHook {
    // #region structs.

    struct FeesData {
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

    /// @notice Sets the fee configuration for a given pool.
    /// @dev Only callable by the vault executor associated with the module.
    /// @param poolKey_ The PoolKey identifying the pool for which to set fees.
    /// @param data_ The FeesData struct containing the module address and fee values.
    function setFees(
        PoolKey calldata poolKey_,
        FeesData calldata data_
    ) external;

    // #region view functions.
    function manager() external view returns (address);
    function feesData(
        PoolId id_
    )
        external
        view
        returns (
            address module,
            uint24 zeroForOneFee,
            uint24 oneForZeroFee
        );

    /// @notice Returns the fee configuration for a given pool.
    /// @param id_ The PoolId for which to retrieve the fee data.
    /// @return module The address of the module associated with the pool.
    /// @return zeroForOneFee The fee for zeroForOne swaps (after removing override flag).
    /// @return oneForZeroFee The fee for oneForZero swaps (after removing override flag).
    function getFeesData(
        PoolId id_
    )
        external
        view
        returns (
            address module,
            uint24 zeroForOneFee,
            uint24 oneForZeroFee
        );
    // #endregion view functions.

    // #region pure functions.

    /// @notice Returns the hook permissions for ArrakisPrivateHook.
    /// @dev Specifies which hooks are enabled or disabled for this contract.
    function getHookPermissions()
        external
        pure
        returns (Hooks.Permissions memory);

    // #endregion pure functions.
}
