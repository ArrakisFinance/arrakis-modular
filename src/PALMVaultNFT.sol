// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// import {NFTSVG} from "./libraries/NFTSVG.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPALMVaultNFT} from "./interfaces/IPALMVaultNFT.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";

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

    function tokenURI(uint256 tokenId_) public view override returns (string memory) {
        IArrakisMetaVault vault = IArrakisMetaVault(address(uint160(tokenId_)));
        (uint256 amount0, uint256 amount1) = vault.totalUnderlying();
        IERC20 token0 = IERC20(vault.token0());
        IERC20 token1 = IERC20(vault.token1());

        // return NFTSVG.generateTokenURI(
        //     NFTSVG.SVGParams({
        //         amount0: amount0,
        //         amount1: amount1,
        //         decimals0: token0.decimals(),
        //         decimals1: token1.decimals(),
        //         symbol0: token0.symbol(),
        //         symbol1: token1.symbol()
        //     })
        // );

        return "mock tokenURI";
    }
}
