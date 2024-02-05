// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../utils/TestWrapper.sol";

import {Guardian} from "../../src/Guardian.sol";
import {IGuardian} from "../../src/interfaces/IGuardian.sol";

contract GuardianTest is TestWrapper {
    address public owner;
    address public pauser;

    Guardian public guardian;

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

    // #endregion test constructor.

    // #region test setPauser.

    function testSetPauserOnlyOwner() public {

    }

    // #endregion test set Pauser.
}