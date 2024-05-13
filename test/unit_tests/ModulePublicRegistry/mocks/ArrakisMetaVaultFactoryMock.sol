// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ArrakisMetaVaultFactoryMock {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal publicVaults;

    function addPublicVault(address publicVault_) external {
        publicVaults.add(publicVault_);
    }

    function isPublicVault(address vault_) external returns (bool) {
        return publicVaults.contains(vault_);
    }
}
