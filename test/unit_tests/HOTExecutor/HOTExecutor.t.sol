// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// #region forge.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion forge.

import {HOTExecutor} from "../../../src/modules/HOTExecutor.sol";
import {IHOTExecutor} from "../../../src/interfaces/IHOTExecutor.sol";
import {IValantisHOTModule} from
    "../../../src/interfaces/IValantisHOTModule.sol";

// #region mocks.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManagerMock.sol";
// #endregion mocks.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract HOTExecutorTest is TestWrapper {
    address public vault;
    address public manager;
    address public owner;
    address public w3f;
    HOTExecutor public executor;

    function setUp() public {
        vault = address(new ArrakisMetaVaultMock());
        manager = address(new ArrakisStandardManagerMock());

        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        w3f =
            vm.addr(uint256(keccak256(abi.encode("Web 3 Function"))));

        executor = new HOTExecutor(manager, w3f, owner);
    }

    // #region test constructor.

    function testConstrutctorManagerAddressZero() public {
        vm.expectRevert(IHOTExecutor.AddressZero.selector);
        executor = new HOTExecutor(address(0), w3f, owner);
    }

    function testConstructorW3FAddressZero() public {
        vm.expectRevert(IHOTExecutor.AddressZero.selector);
        executor = new HOTExecutor(manager, address(0), owner);
    }

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IHOTExecutor.AddressZero.selector);
        executor = new HOTExecutor(manager, w3f, address(0));
    }

    // #endregion test constructor.

    // #region test setW3F.

    function testSetW3FOnlyOwner() public {
        address newW3F =
            vm.addr(uint256(keccak256(abi.encode("New W3F"))));
        vm.expectRevert(Ownable.Unauthorized.selector);
        executor.setW3f(newW3F);
    }

    function testSetW3FAddressZero() public {
        vm.expectRevert(IHOTExecutor.AddressZero.selector);
        vm.prank(owner);
        executor.setW3f(address(0));
    }

    function testSetW3FSameW3f() public {
        vm.expectRevert(IHOTExecutor.SameW3f.selector);
        vm.prank(owner);
        executor.setW3f(w3f);
    }

    function testSetW3F() public {
        address newW3F =
            vm.addr(uint256(keccak256(abi.encode("New W3F"))));
        vm.prank(owner);
        executor.setW3f(newW3F);

        assertEq(newW3F, executor.w3f());
    }

    // #endregion test setW3F.

    // #region test setModule.

    function testSetModuleOnlyOwnerOrW3F() public {
        address notOwner =
            vm.addr(uint256(keccak256(abi.encode("Not Owner"))));
        address module =
            vm.addr(uint256(keccak256(abi.encode("Module"))));
        bytes[] memory payloads = new bytes[](0);

        vm.expectRevert(IHOTExecutor.OnlyOwnerOrW3F.selector);
        vm.prank(notOwner);
        executor.setModule(vault, module, payloads);
    }

    function testSetModule() public {
        address notOwner =
            vm.addr(uint256(keccak256(abi.encode("Not Owner"))));
        address module =
            vm.addr(uint256(keccak256(abi.encode("Module"))));
        bytes[] memory payloads = new bytes[](0);

        vm.prank(owner);
        executor.setModule(vault, module, payloads);
    }

    function testSetModuleBis() public {
        address notOwner =
            vm.addr(uint256(keccak256(abi.encode("Not Owner"))));
        address module =
            vm.addr(uint256(keccak256(abi.encode("Module"))));
        bytes[] memory payloads = new bytes[](0);

        vm.prank(w3f);
        executor.setModule(vault, module, payloads);
    }

    // #endregion test setModule.

    // #region test rebalance.

    function testRebalanceOnlyW3F() public {
        bytes[] memory payloads = new bytes[](0);

        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        uint256 expectedReservesAmounts = 1 ether;
        bool zeroForOne = true;

        vm.prank(caller);
        vm.expectRevert(IHOTExecutor.OnlyOwnerOrW3F.selector);
        executor.rebalance(
            vault, payloads, expectedReservesAmounts, zeroForOne
        );
    }

    function testRebalanceUnexpectedReservesAmount0() public {
        bytes[] memory payloads = new bytes[](1);

        payloads[0] =
            abi.encodeWithSelector(IValantisHOTModule.swap.selector);
        uint256 expectedReservesAmounts = 1 ether;
        bool zeroForOne = true;

        vm.prank(w3f);
        vm.expectRevert(
            IHOTExecutor.UnexpectedReservesAmount0.selector
        );
        executor.rebalance(
            vault, payloads, expectedReservesAmounts, zeroForOne
        );
    }

    function testRebalanceUnexpectedReservesAmount1() public {
        bytes[] memory payloads = new bytes[](1);

        payloads[0] =
            abi.encodeWithSelector(IValantisHOTModule.swap.selector);
        uint256 expectedReservesAmounts = 1 ether;
        bool zeroForOne = false;

        vm.prank(owner);
        vm.expectRevert(
            IHOTExecutor.UnexpectedReservesAmount1.selector
        );
        executor.rebalance(
            vault, payloads, expectedReservesAmounts, zeroForOne
        );
    }

    function testRebalance() public {
        bytes[] memory payloads = new bytes[](1);

        payloads[0] =
            abi.encodeWithSelector(IValantisHOTModule.swap.selector);
        uint256 expectedReservesAmounts = 1 ether;
        bool zeroForOne = false;

        ArrakisMetaVaultMock(vault).setAmounts(0, 1 ether);

        vm.prank(w3f);
        executor.rebalance(
            vault, payloads, expectedReservesAmounts, zeroForOne
        );
    }

    function testRebalanceBis() public {
        bytes[] memory payloads = new bytes[](1);

        payloads[0] =
            abi.encodeWithSelector(IValantisHOTModule.swap.selector);
        uint256 expectedReservesAmounts = 1 ether;
        bool zeroForOne = true;

        ArrakisMetaVaultMock(vault).setAmounts(1 ether, 0);

        vm.prank(w3f);
        executor.rebalance(
            vault, payloads, expectedReservesAmounts, zeroForOne
        );
    }

    // #endregion test rebalance.
}
