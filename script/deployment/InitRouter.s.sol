// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisPublicVaultRouter} from
    "../../src/ArrakisPublicVaultRouter.sol";

contract InitRouter is Script {
    address public constant router =
        0xFf24347dA277476d11c462Ea7314BA04fb8Fb793;
    address public constant routerExecutor =
        0xBd6C1799f8433154e978De1b080235ff9beFC15A;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        address deployer = ArrakisRoles.getOwner();

        console.logString("Deployer :");
        console.logAddress(deployer);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisPublicVaultRouter.updateSwapExecutor.selector,
            routerExecutor
        );

        console.logString("Payload Public registry :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(router);
    }
}
