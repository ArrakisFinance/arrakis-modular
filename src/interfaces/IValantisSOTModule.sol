// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignPool} from "./ISovereignPool.sol";
import {ISovereignALM} from "./ISovereignALM.sol";

interface IValantisModule {
    // #region errors.

    error NoNativeToken();
    error OnlyPool(address caller, address pool);
    error TotalSupplyZero();
    error Actual0DifferentExpected(uint256 actual0, uint256 expected0);
    error Actual1DifferentExpected(uint256 actual1, uint256 expected1);
    error NotImplemented();

    // #endregion errors.

    // #region state modifying functions.

    /// @notice function used to set new manager
    /// @dev setting a manager different than the module,
    /// will make the module unusable.
    /// let's make it not implemented for now
    function setManager(address newManager_) external;

    // #endregion state modifiying functions.

    // #region view functions.

    /// @notice function used to get the valantis sot pool.
    function pool() external view returns (ISovereignPool);

    /// @notice function used to get the valantis sot alm/ liquidity module.
    function alm() external view returns (ISovereignALM);

    // #endregion view functions.
}
