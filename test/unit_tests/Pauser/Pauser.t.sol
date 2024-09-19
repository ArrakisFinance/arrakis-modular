// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {Pauser, IPauser} from "../../../src/Pauser.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #region mock contract.

import {BeaconToPause} from "./mocks/BeaconToPause.sol";

// #endregion mock contract.

contract PauserTest is TestWrapper {

    address public pauser0;
    address public pauser1;

    Pauser public pauserContract;
    BeaconToPause public beaconToPause;

    address public owner;

    function setUp() public {
        pauser0 = vm.addr(uint256(keccak256(abi.encode("Pauser0"))));
        pauser1 = vm.addr(uint256(keccak256(abi.encode("Pauser1"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        pauserContract = new Pauser(pauser0, owner);

        beaconToPause = new BeaconToPause();
    }

    // #region test constructor.

    function testConstructorAddressZeroPauser() public {
        vm.expectRevert(IPauser.AddressZero.selector);

        pauserContract = new Pauser(address(0), owner);
    }

    function testConstructorAddressZeroOwner() public {
        vm.expectRevert(IPauser.AddressZero.selector);

        pauserContract = new Pauser(pauser0, address(0));
    }

    function testConstructor() public {
        pauserContract = new Pauser(pauser0, owner);

        assertEq(pauserContract.owner(), owner);
        assert(pauserContract.isPauser(pauser0));
    }

    // #endregion test constructor.

    // #region test pause.

    function testPauseNotPauser() public {
        vm.expectRevert(IPauser.OnlyPauser.selector);

        pauserContract.pause(address(beaconToPause));
    }

    function testPause() public {
        address[] memory pausers = new address[](1);
        pausers[0] = pauser1;
        vm.prank(owner);
        pauserContract.whitelistPausers(pausers);

        vm.prank(pauser1);
        pauserContract.pause(address(beaconToPause));

        assert(beaconToPause.paused());
    }

    // #endregion test pause.

    // #region test whitelistPausers.

    function testWhiteListPausersOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory pausers = new address[](1);
        pausers[0] = pauser1;
        vm.prank(pauser0);
        pauserContract.whitelistPausers(pausers);
    }

    function testWhiteListPausersAddressZero() public {
        vm.expectRevert(IPauser.AddressZero.selector);

        address[] memory pausers = new address[](1);
        pausers[0] = address(0);
        vm.prank(owner);
        pauserContract.whitelistPausers(pausers);
    }

    function testWhiteListPausersAlreadyPauser() public {
        vm.expectRevert(IPauser.AlreadyPauser.selector);

        address[] memory pausers = new address[](1);
        pausers[0] = pauser0;
        vm.prank(owner);
        pauserContract.whitelistPausers(pausers);
    }

    function testWhiteListPausers() public {
        address[] memory pausers = new address[](1);
        pausers[0] = pauser1;
        vm.prank(owner);
        pauserContract.whitelistPausers(pausers);

        assert(pauserContract.isPauser(pauser1));
    }

    // #endregion test whitelistPausers.

    // #region test blacklistPausers.

    function testBlackListPausersOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        address[] memory pausers = new address[](1);
        pausers[0] = pauser0;
        vm.prank(pauser0);
        pauserContract.blacklistPausers(pausers);
    }

    function testBlackListPausersNotPauser() public {
        vm.expectRevert(IPauser.NotPauser.selector);

        address[] memory pausers = new address[](1);
        pausers[0] = pauser1;
        vm.prank(owner);
        pauserContract.blacklistPausers(pausers);
    }

    function testBlackListPausers() public {
        address[] memory pausers = new address[](1);
        pausers[0] = pauser1;
        vm.prank(owner);
        pauserContract.whitelistPausers(pausers);

        vm.prank(owner);
        pauserContract.blacklistPausers(pausers);

        assert(!pauserContract.isPauser(pauser1));
    }

    // #endregion test blacklistPausers.

    // #region test isPauser.

    function testIsPauser() public {
        assert(pauserContract.isPauser(pauser0));
        assert(!pauserContract.isPauser(pauser1));
    }

    // #endregion test isPauser.

}