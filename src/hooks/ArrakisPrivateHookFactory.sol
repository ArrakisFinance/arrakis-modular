// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisPrivateHookFactory} from
    "../interfaces/IArrakisPrivateHookFactory.sol";
import {ArrakisPrivateHook} from "./ArrakisPrivateHook.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {Create3} from "@create3/contracts/Create3.sol";

contract ArrakisPrivateHookFactory is IArrakisPrivateHookFactory, Ownable {
    constructor (address owner_) {
        if (owner_ == address(0)) {
            revert AddressZero();
        }
        _initializeOwner(owner_);
    }

    function createPrivateHook(
        address module_,
        bytes32 salt_
    ) external override returns (address hook) {
        address _owner = owner();
        if (_owner != address(0)) {
            _checkOwner();
        }

        bytes memory creatonCode = abi.encodePacked(
            type(ArrakisPrivateHook).creationCode,
            abi.encode(module_)
        );

        return Create3.create3(salt_, creatonCode);
    }

    function addressOf(bytes32 salt_) external view returns (address) {
        return Create3.addressOf(salt_);
    }
}
