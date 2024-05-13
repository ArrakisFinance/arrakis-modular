// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IPALMVaultNFT} from "./interfaces/IPALMVaultNFT.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract PALMVaultNFT is Ownable, ERC721, IPALMVaultNFT {
    constructor() ERC721("Arrakis Modular PALM Vaults", "PALM") {
        _initializeOwner(msg.sender);
    }

    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external onlyOwner {
        _mint(to_, tokenId_);
    }
}
