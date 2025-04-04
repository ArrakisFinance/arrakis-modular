// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisPrivateHookFactory} from
    "../interfaces/IArrakisPrivateHookFactory.sol";
import {ArrakisPrivateHook} from "./ArrakisPrivateHook.sol";

import {Create3} from "@create3/contracts/Create3.sol";

contract ArrakisPrivateHookFactory is IArrakisPrivateHookFactory {
    function createPrivateHook(
        address module_,
        bytes32 salt_
    ) external override returns (address hook) {
        bytes memory creationCode = abi.encodePacked(
            type(ArrakisPrivateHook).creationCode,
            abi.encode(module_)
        );

        bytes32 salt = keccak256(abi.encode(msg.sender, salt_));

        hook = Create3.create3(salt, creationCode);

        emit LogCreatePrivateHook(hook, module_, salt_);

        return hook;
    }

    function addressOf(bytes32 salt_) external view returns (address) {
        return Create3.addressOf(salt_);
    }
}
