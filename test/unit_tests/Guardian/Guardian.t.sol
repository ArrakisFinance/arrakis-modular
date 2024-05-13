// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {Guardian} from "../../../src/Guardian.sol";
import {IGuardian} from "../../../src/interfaces/IGuardian.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract GuardianTest is TestWrapper {
    address public owner;
    address public pauser;

    Guardian public guardian;

    // #region expected event to be emitted.

    event LogSetPauser(address oldPauser, address newPauser);

    // #endregion expected event to be emitted.

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        guardian = new Guardian(owner, pauser);
    }

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IGuardian.AddressZero.selector);

        guardian = new Guardian(address(0), pauser);
    }

    function testConstructorPauserAddressZero() public {
        vm.expectRevert(IGuardian.AddressZero.selector);

        guardian = new Guardian(owner, address(0));
    }

    function testConstructor() public {
        vm.expectEmit();

        emit LogSetPauser(address(0), pauser);

        guardian = new Guardian(owner, pauser);

        assertEq(guardian.owner(), owner);
        assertEq(guardian.pauser(), pauser);
    }

    // #endregion test constructor.

    // #region test setPauser.

    function testSetPauserOnlyOwner() public {
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));
        address newPauser =
            vm.addr(uint256(keccak256(abi.encode("NewPauser"))));

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        guardian.setPauser(newPauser);
    }

    function testSetPauserNewPauserAddressZero() public {
        vm.prank(owner);
        vm.expectRevert(IGuardian.AddressZero.selector);

        guardian.setPauser(address(0));
    }

    function testSetPauserSamePauser() public {
        vm.prank(owner);
        vm.expectRevert(IGuardian.SamePauser.selector);

        guardian.setPauser(pauser);
    }

    function testSetPauser() public {
        address newPauser =
            vm.addr(uint256(keccak256(abi.encode("NewPauser"))));

        vm.prank(owner);
        vm.expectEmit();

        emit LogSetPauser(pauser, newPauser);

        guardian.setPauser(newPauser);

        assertEq(guardian.pauser(), newPauser);
    }

    // #endregion test set Pauser.
}
