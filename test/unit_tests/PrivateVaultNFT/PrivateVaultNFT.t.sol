// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {TestWrapper} from "../../utils/TestWrapper.sol";
import {console} from "forge-std/console.sol";

// #endregion foundry.

import {IPrivateVaultNFT} from
    "../../../src/interfaces/IPrivateVaultNFT.sol";
import {PrivateVaultNFT} from "../../../src/PrivateVaultNFT.sol";
import {NFTSVG} from "../../../src/utils/NFTSVG.sol";

contract PrivateVaultNFTTest is TestWrapper {
    address public nft;
    address public owner;
    address public svgController;
    address public renderer;

    function setUp() external {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        svgController =
            vm.addr(uint256(keccak256(abi.encode("SvgController"))));

        vm.prank(owner);
        nft = address(new PrivateVaultNFT());

        renderer = address(new NFTSVG());
    }

    // #region test initialize.

    function testInitializeSvgControllerAddressZero() public {
        vm.expectRevert(IPrivateVaultNFT.AddressZero.selector);
        IPrivateVaultNFT(nft).initialize(address(0));
    }

    function testInitialize() public {
        IPrivateVaultNFT(nft).initialize(svgController);

        assertEq(svgController, IPrivateVaultNFT(nft).svgController());
    }

    // #endregion test initialize.

    // #region test setRenderer.

    function testSetRendererOnlySvgController() public {
        IPrivateVaultNFT(nft).initialize(svgController);
        vm.expectRevert(IPrivateVaultNFT.OnlySvgController.selector);
        IPrivateVaultNFT(nft).setRenderer(renderer);
    }

    function testSetRendererInvalidRenderer() public {
        address rend =
            vm.addr(uint256(keccak256(abi.encode("Renderer"))));
        IPrivateVaultNFT(nft).initialize(svgController);
        vm.expectRevert(IPrivateVaultNFT.InvalidRenderer.selector);
        vm.prank(svgController);
        IPrivateVaultNFT(nft).setRenderer(rend);
    }

    function testSetRenderer() public {
        IPrivateVaultNFT(nft).initialize(svgController);
        vm.prank(svgController);
        IPrivateVaultNFT(nft).setRenderer(renderer);
    }

    // #endregion test setRenderer.
}
