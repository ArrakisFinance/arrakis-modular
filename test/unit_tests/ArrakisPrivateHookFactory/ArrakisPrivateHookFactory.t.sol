// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPrivateHookFactory} from
    "../../../src/interfaces/IArrakisPrivateHookFactory.sol";
import {IArrakisPrivateHook} from
    "../../../src/interfaces/IArrakisPrivateHook.sol";
import {ArrakisPrivateHookFactory} from
    "../../../src/hooks/ArrakisPrivateHookFactory.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {Create3} from "@create3/contracts/Create3.sol";

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

// #region mock contract.

import {ModuleMock} from "./mocks/ModuleMock.sol";

// #endregion mock contract.

contract ArrakisPrivateHookFactoryTest is TestWrapper {
    address public module;

    function setUp() public {
        module = vm.addr(uint256(keccak256(abi.encode("Module"))));
    }

    // #region create hook.

    function test_create_private_hook_module_hook_address() public {
        ArrakisPrivateHookFactory factory =
            new ArrakisPrivateHookFactory();

        vm.expectRevert(Create3.ErrorCreatingContract.selector);
        factory.createPrivateHook(module, bytes32(0));
    }

    function test_create_private_hook() public {
        module = address(new ModuleMock());

        ArrakisPrivateHookFactory factory =
            new ArrakisPrivateHookFactory();

        Hooks.Permissions memory perm = Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });

        // #region to generate the salt.

        // bytes32 salt;
        // bytes32 s;

        // for (uint256 i = 0; i < 100000; i++) {
        //     salt = keccak256(abi.encode(address(this), bytes32(i)));
        //     address hookAddr = factory.addressOf(salt);

        //     try this.valideAddr(IHooks(hookAddr), perm) {
        //         s = bytes32(i);
        //         break;
        //     } catch {
        //         salt = bytes32(0);
        //         continue;
        //     }
        // }

        // if (salt == bytes32(0)) {
        //     vm.expectRevert(Create3.ErrorCreatingContract.selector);
        // } else {
        //     console.logBytes32(salt);
        //     console.logBytes32(s);
        // }

        // #endregion to generate the salt.

        // address expectedHookAddress = factory.addressOf(salt);
        address expectedHookAddress = factory.addressOf(0xb3f7d430e00eab1bbbe932d150f9c94ba144afe683cd4b1bff72b7a63ac8d57d);

        // address hook = factory.createPrivateHook(module, s);
        address hook = factory.createPrivateHook(
            module,
            0x00000000000000000000000000000000000000000000000000000000000032af
        );

        assertEq(hook, expectedHookAddress);
    }

    // #endregion create hook.

    // function valideAddr(
    //     IHooks hooks,
    //     Hooks.Permissions memory perm
    // ) external returns (bool) {
    //     Hooks.validateHookPermissions(hooks, perm);
    // }
}
