// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {UniV4StandardModuleResolver} from "../../src/modules/resolvers/UniV4StandardModuleResolver.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

// Resolver : 0x9f87Be2d451F39B48AD222Ae9Cd91be442F5E9F9
contract DUniswapV4Resolver is CreateXScript {
    uint88 public version = uint88(
        uint256(keccak256(abi.encode("Resolver Uniswap V4 version 1")))
    );

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        address poolManager = getPoolManager();

        bytes memory initCode = abi.encodePacked(
            type(UniV4StandardModuleResolver).creationCode,
            abi.encode(poolManager)
        );

        bytes32 salt = bytes32(
            abi.encodePacked(msg.sender, hex"00", bytes11(version))
        );

        address resolver =
            computeCreate3Address(salt, msg.sender);

        console.logString("Resolver Uniswap V4 Address : ");
        console.logAddress(resolver);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Resolver Address :");
        console.logAddress(actualAddr);

        if (resolver != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }

    function getPoolManager() public view returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x000000000004444c5dc75cB358380D2e3dE08A90;
        }
        // polygon
        else if (chainId == 137) {
            return 0x67366782805870060151383F4BbFF9daB53e5cD6;
        }
        // optimism
        else if (chainId == 10) {
            return 0x9a13F98Cb987694C9F086b1F5eB990EeA8264Ec3;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // base sepolia
        else if (chainId == 84_531) {
            return 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // binance
        else if (chainId == 56) {
            return 0x28e2Ea090877bF75740558f6BFB36A5ffeE9e9dF;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
    }
}
