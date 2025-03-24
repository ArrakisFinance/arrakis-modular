// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    ArrakisPrivateHook,
    Hooks,
    IHooks
} from "../../../../src/hooks/ArrakisPrivateHook.sol";

contract ArrakisPrivateHookImplementation is ArrakisPrivateHook {
    constructor(
        address manager_,
        ArrakisPrivateHook addressToEtch
    ) ArrakisPrivateHook(manager_) {
        Hooks.validateHookPermissions(
            addressToEtch, getHookPermissions()
        );
    }

    function _validateHookAddress(
        IHooks _this
    ) internal pure override {}
}
