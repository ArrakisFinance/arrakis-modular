// SPDX-License-Identifier: UNLISENSED
pragma solidity 0.8.19;

// #region foundry.

import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";

// #endregion foundry.

import {IHOTCoordinator} from
    "../../../src/interfaces/IHOTCoordinator.sol";
import {HOTCoordinator} from "../../../src/modules/HOTCoordinator.sol";

// #region mocks.

import {HOTMock, NotHOT} from "./mocks/HOTMock.sol";

// #endregion mocks.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract HOTCoordinatorTest is TestWrapper {
    address public hot;
    /// @dev timelock is the owner of the contract.
    address public timelock;
    address public responder;
    address public hotCoordinator;

    function setUp() public {
        hot = address(new HOTMock());
        timelock = vm.addr(uint256(keccak256(abi.encode("Timelock"))));
        responder =
            vm.addr(uint256(keccak256(abi.encode("Responder"))));

        hotCoordinator =
            address(new HOTCoordinator(responder, timelock));
    }

    // #region test constructor.

    function testConstructorResponderAddressZero() public {
        vm.expectRevert(IHOTCoordinator.AddressZero.selector);
        new HOTCoordinator(address(0), timelock);
    }

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IHOTCoordinator.AddressZero.selector);
        new HOTCoordinator(responder, address(0));
    }

    function testConstructor() public {
        assertEq(
            HOTCoordinator(hotCoordinator).responder(), responder
        );
        assertEq(HOTCoordinator(hotCoordinator).owner(), timelock);
    }

    // #endregion test constructor.

    // #region test setResponder.

    function testSetResponderOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        HOTCoordinator(hotCoordinator).setResponder(address(0));
    }

    function testSetResponderAddressZero() public {
        vm.expectRevert(IHOTCoordinator.AddressZero.selector);
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).setResponder(address(0));
    }

    function testSetResponderSameResponder() public {
        vm.expectRevert(IHOTCoordinator.SameResponder.selector);
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).setResponder(responder);
    }

    function testSetResponder() public {
        address newResponder =
            vm.addr(uint256(keccak256(abi.encode("NewResponder"))));
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).setResponder(newResponder);
        assertEq(
            HOTCoordinator(hotCoordinator).responder(), newResponder
        );
    }

    // #endregion test setResponder.

    // #region test callHot.

    function testCallHotOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        HOTCoordinator(hotCoordinator).callHot(hot, "");
    }

    function testCallHotAddressZero() public {
        vm.expectRevert(IHOTCoordinator.AddressZero.selector);
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).callHot(address(0), "");
    }

    function testCallHotEmptyData() public {
        vm.expectRevert(IHOTCoordinator.EmptyData.selector);
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).callHot(hot, "");
    }

    function testCallHotCallFailed() public {
        bytes memory data =
            abi.encodeWithSelector(NotHOT.testCallFailed.selector);
        vm.expectRevert(IHOTCoordinator.CallFailed.selector);
        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).callHot(hot, data);
    }

    function testCallHot() public {
        address newManager =
            vm.addr(uint256(keccak256(abi.encode("NewManager"))));
        bytes memory data = abi.encodeWithSelector(
            HOTMock.setManager.selector, newManager
        );

        vm.prank(timelock);
        HOTCoordinator(hotCoordinator).callHot(hot, data);
    }

    // #endregion test callHot.

    // #region test setMaxTokenVolumes.

    function testSetMaxTokenVolumesOnlyResponder() public {
        vm.expectRevert(IHOTCoordinator.OnlyResponder.selector);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(hot, 0, 0);
    }

    function testSetMaxTokenVolumesIncreaseMaxVolume() public {
        vm.prank(responder);
        vm.expectRevert(IHOTCoordinator.IncreaseMaxVolume.selector);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(hot, 0, 0);
    }

    function testSetMaxTokenVolumesIncreaseMaxVolumeBis() public {
        HOTMock(hot).setTokenVolumes(1000, 0);

        vm.prank(responder);
        vm.expectRevert(IHOTCoordinator.IncreaseMaxVolume.selector);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(hot, 0, 0);
    }

    function testSetMaxTokenVolumesIncreaseMaxVolume2Bis() public {
        HOTMock(hot).setTokenVolumes(0, 200);

        vm.prank(responder);
        vm.expectRevert(IHOTCoordinator.IncreaseMaxVolume.selector);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(hot, 0, 0);
    }

    function testSetMaxTokenVolumes() public {
        HOTMock(hot).setTokenVolumes(1000, 200);

        vm.prank(responder);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(hot, 0, 0);
    }

    function testSetMaxTokenVolumesBis() public {
        HOTMock(hot).setTokenVolumes(100_000, 20_000);

        vm.prank(responder);
        HOTCoordinator(hotCoordinator).setMaxTokenVolumes(
            hot, 10_000, 2000
        );
    }

    // #endregion test setMaxTokenVolumes.

    // #region test setPause.

    function testSetPauseOnlyResponder() public {
        vm.expectRevert(IHOTCoordinator.OnlyResponder.selector);
        HOTCoordinator(hotCoordinator).setPause(hot, true);
    }

    function testSetPause() public {
        vm.prank(responder);
        HOTCoordinator(hotCoordinator).setPause(hot, true);
    }

    // #endregion test setPause.
}
