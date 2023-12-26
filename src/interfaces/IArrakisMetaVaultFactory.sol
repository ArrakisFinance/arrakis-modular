// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaVault} from "./IArrakisMetaVault.sol";

interface IArrakisMetaVaultFactory {

    // #region errors.

    error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);
    error EndIndexGtNbOfVaults(uint256 endIndex, uint256 numberOfVaults);

    // #endregion errors.

    // #region events.

    event LogTokenVaultCreation(address indexed creator, address tokenVault);
    event LogOwnedVaultCreation(address indexed creator, address ownedVault);

    // #endregion events.
}