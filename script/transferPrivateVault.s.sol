// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IArrakisMetaVault} from "../src/interfaces/IArrakisMetaVault.sol";


/// @dev before this script we should whitelist the deployer as public vault deployer using the multisig
/// on the factory side©.

address constant nft = 0x44A801e7E2E073bd8bcE4bCCf653239Fa156B762;
uint256 constant tokenId = uint256(uint160(0xE74d6255f02c11DEf852FD2843a03c6e128b9441));
address constant newOwner = 0xB453Cb3b96101e597eF0CF201a92777f721849ae;

// oracle : 0x2f7989F3C6E3462e028a4Fa23F570805F1EE9fEb 

contract TransferPrivateVault is Script {
    function setUp() public {}

    function run() public {

        vm.startPrank(newOwner);

        console.logString("Deployer : ");
        console.logAddress(msg.sender);

        // vm.startBroadcast();

        console.log(ERC721(nft).balanceOf(newOwner));
        console.logAddress(ERC721(nft).ownerOf(tokenId));

        // IArrakisMetaVault(0xE74d6255f02c11DEf852FD2843a03c6e128b9441).withdraw(1e18, newOwner);

        // ERC721(nft).transferFrom(account, newOwner, tokenId);

        console.logString("Ownership transferred");

        vm.stopPrank();
        // vm.stopBroadcast();
    }
}
