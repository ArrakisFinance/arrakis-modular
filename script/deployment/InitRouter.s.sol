// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisPublicVaultRouter} from
    "../../src/ArrakisPublicVaultRouter.sol";

contract InitRouter is Script {
    address public constant router =
        0x72aa2C8e6B14F30131081401Fa999fC964A66041;
    address public constant routerExecutor =
        0x19488620Cdf3Ff1B0784AC4529Fb5c5AbAceb1B6;

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
