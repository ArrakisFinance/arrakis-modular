// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {RouterSwapExecutor} from "../../src/RouterSwapExecutor.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

// RouterExecutor : 0x19488620Cdf3Ff1B0784AC4529Fb5c5AbAceb1B6
// RouterExecutor V2 : 0x31e1A0ac6931a9c5BFe149596CcDc9C37C558e54 (salt = "Router V2 Executor version 1")
// RouterExecutor V2 : 0x132003c8250142d92DBDC6C7DA098897B35Fa151 (salt = "Router V2 Executor version 1.0.1")
// RouterExecutor V2 : 0xcaaF0c8c3F3C4662A54789F493D851cdC34AeFFD (salt = "Router V2 Executor version 1.0.2") Sepolia
contract DRouterExecutor is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Router V2 Executor version 1.0.2")))
    );

    address public constant router =
        0xB01e27e9560139eb01956522d8C2CAF0ec51DaD7;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        bytes memory initCode = abi.encodePacked(
            type(RouterSwapExecutor).creationCode,
            abi.encode(router, NATIVE_COIN)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address routerExecutor =
            computeCreate3Address(salt, msg.sender);

        console.logString("Router Executor Address : ");
        console.logAddress(routerExecutor);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Router Executor Address :");
        console.logAddress(actualAddr);

        if (routerExecutor != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
