// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ArrakisMetaVaultFactoryMock {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal privateVaults;

    function addPrivateVault(address privateVault_) external {
        privateVaults.add(privateVault_);
    }

    function isPrivateVault(address vault_) external returns (bool) {
        return privateVaults.contains(vault_);
    }
}
