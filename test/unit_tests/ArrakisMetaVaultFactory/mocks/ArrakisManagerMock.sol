// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IManager} from "../../../../src/interfaces/IManager.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ArrakisManagerMock is IManager {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _vaults;

    function initManagement(address vault_) external {
        _vaults.add(vault_);
    }

    function isManaged(address vault_) external view returns (bool) {
        return _vaults.contains(vault_);
    }

    function getInitManagementSelector()
        external
        pure
        returns (bytes4)
    {
        return this.initManagement.selector;
    }
}
