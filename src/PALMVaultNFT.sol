// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract PALMVaultNFT is Ownable, ERC721 {
    constructor() ERC721("Arrakis Modular PALM Vaults", "PALM") {
        _initializeOwner(msg.sender);
    }

    function mint(address to_, uint256 tokenId_) external onlyOwner {
        _mint(to_, tokenId_);
    }
}