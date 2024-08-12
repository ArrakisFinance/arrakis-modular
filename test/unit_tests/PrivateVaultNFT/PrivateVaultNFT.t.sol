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
    address public announcer;
    address public renderer;

    function setUp() external {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        announcer =
            vm.addr(uint256(keccak256(abi.encode("Announcer"))));

        vm.prank(owner);
        nft = address(new PrivateVaultNFT());

        renderer = address(new NFTSVG());
    }

    // #region test initialize.

    function testInitializeAnnouncerAddressZero() public {
        vm.expectRevert(IPrivateVaultNFT.AddressZero.selector);
        IPrivateVaultNFT(nft).initialize(address(0));
    }

    function testInitialize() public {
        IPrivateVaultNFT(nft).initialize(announcer);

        assertEq(announcer, IPrivateVaultNFT(nft).announcer());
    }

    // #endregion test initialize.

    // #region test setRenderer.

    function testSetRendererOnlyAnnouncer() public {
        IPrivateVaultNFT(nft).initialize(announcer);
        vm.expectRevert(IPrivateVaultNFT.OnlyAnnouncer.selector);
        IPrivateVaultNFT(nft).setRenderer(renderer);
    }

    function testSetRendererInvalidRenderer() public {
        address rend =
            vm.addr(uint256(keccak256(abi.encode("Renderer"))));
        IPrivateVaultNFT(nft).initialize(announcer);
        vm.expectRevert(IPrivateVaultNFT.InvalidRenderer.selector);
        vm.prank(announcer);
        IPrivateVaultNFT(nft).setRenderer(rend);
    }

    function testSetRenderer() public {
        IPrivateVaultNFT(nft).initialize(announcer);
        vm.prank(announcer);
        IPrivateVaultNFT(nft).setRenderer(renderer);
    }

    // #endregion test setRenderer.
}
