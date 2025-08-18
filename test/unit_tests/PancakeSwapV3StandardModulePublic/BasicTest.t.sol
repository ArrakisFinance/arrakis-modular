// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {PancakeSwapV3StandardModulePublic} from
    "../../../src/modules/PancakeSwapV3StandardModulePublic.sol";

contract BasicPancakeSwapV3Test is Test {
    PancakeSwapV3StandardModulePublic public module;
    
    address constant GUARDIAN = 0x1111111111111111111111111111111111111111;
    address constant NFT_MANAGER = 0x2222222222222222222222222222222222222222;
    address constant FACTORY = 0x3333333333333333333333333333333333333333;
    address constant CAKE = 0x4444444444444444444444444444444444444444;
    address constant MASTERCHEF = 0x5555555555555555555555555555555555555555;

    function test_BasicDeployment() public {
        module = new PancakeSwapV3StandardModulePublic(
            GUARDIAN,
            NFT_MANAGER,
            FACTORY,
            CAKE,
            MASTERCHEF
        );

        assertEq(module.nftPositionManager(), NFT_MANAGER);
        assertEq(module.factory(), FACTORY);
        assertEq(module.CAKE(), CAKE);
        assertEq(module.masterChefV3(), MASTERCHEF);
    }

    function test_Id() public {
        module = new PancakeSwapV3StandardModulePublic(
            GUARDIAN,
            NFT_MANAGER,
            FACTORY,
            CAKE,
            MASTERCHEF
        );

        assertEq(
            module.id(),
            0x918c66e50fd8ae37316bc2160d5f23b3f5d59ccd1972c9a515dc2f8ac22875b6
        );
    }
}