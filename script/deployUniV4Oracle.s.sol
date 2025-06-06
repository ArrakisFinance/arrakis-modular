// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";

import {UniV4Oracle} from "../src/oracles/UniV4Oracle.sol";

// IMPORTANT !!! Fill in / check these sensitive varaibles before running script !!!

bool constant isInversed = true;

contract DeployUniV4Oracle is Script {
    function setUp() public {}

    function run() public {
        address poolManager = getPoolManager();

        vm.startBroadcast();

        console.log("Deployer : ");
        console.logAddress(msg.sender);

        // #region create uni V4 oracle.

        address oracle;

        oracle = address(new UniV4Oracle(poolManager, isInversed));

        console.log("Uni V4 Oracle : ");
        console.logAddress(oracle);

        // #endregion create uni V4 oracle.

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
        // sepolia
        else if (chainId == 11_155_111) {
            return 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;
        }
        // base
        else if (chainId == 8453) {
            return 0x498581fF718922c3f8e6A244956aF099B2652b2b;
        }
        // Ink
        else if (chainId == 57_073) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x1F98400000000000000000000000000000000004;
        }
        // Arbitrum
        else if (chainId == 42_161) {
            return 0x360E68faCcca8cA495c1B759Fd9EEe466db9FB32;
        }
        // default
        else {
            revert("Not supported network!");
        }
    }
}
