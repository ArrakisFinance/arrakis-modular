// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {TestWrapper} from "../../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";

// #endregion foundry.

import {IRenderController} from
    "../../../src/interfaces/IRenderController.sol";
import {RenderController} from "../../../src/RenderController.sol";
import {NFTSVG} from "../../../src/utils/NFTSVG.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract RenderControllerTest is TestWrapper {
    address public owner;
    address public renderController;
    address public renderer;

    function setUp() external {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        renderController = address(new RenderController());
        RenderController(renderController).initialize(owner);

        renderer = address(new NFTSVG());
    }

    // #region test initialize.

    function testInitializeOwnerAddressZero() public {
        renderController = address(new RenderController());
        vm.expectRevert(IRenderController.AddressZero.selector);
        RenderController(renderController).initialize(address(0));
    }

    function testInitialize() public {
        renderController = address(new RenderController());
        RenderController(renderController).initialize(owner);

        assertEq(owner, Ownable(renderController).owner());
    }

    // #endregion test initialize.

    // #region test setRenderer.

    function testSetRendererOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);
        IRenderController(renderController).setRenderer(renderer);
    }

    function testSetRendererInvalidRenderer() public {
        address rend =
            vm.addr(uint256(keccak256(abi.encode("Renderer"))));
        vm.expectRevert(IRenderController.InvalidRenderer.selector);
        vm.prank(owner);
        IRenderController(renderController).setRenderer(rend);
    }

    function testSetRenderer() public {
        vm.prank(owner);
        IRenderController(renderController).setRenderer(renderer);
    }

    // #endregion test setRenderer.
}
