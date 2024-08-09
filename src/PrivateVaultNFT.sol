// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {INFTSVG, SVGParams} from "src/libraries/NFTSVG.sol";
import {IPrivateVaultNFT} from "./interfaces/IPrivateVaultNFT.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

error InvalidLibrary();

contract PrivateVaultNFT is Ownable, ERC721, IPrivateVaultNFT {

    address private _library;

    constructor()
        ERC721("Arrakis Private LP NFT", "ARRAKIS")
    {
        _initializeOwner(msg.sender);
    }

    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external onlyOwner {
        _safeMint(to_, tokenId_);
    }

    // TODO: is it correct to have it as onlyOwner? will this be the Arrakis MS?
    function setLibrary(address library_) external onlyOwner {
        if (!INFTSVG(library_).isNFTSVG()) revert InvalidLibrary();
        _library = library_;
    }

    function tokenURI(uint256 tokenId_)
        public
        view
        override
        returns (string memory)
    {
        IArrakisMetaVault vault = IArrakisMetaVault(address(uint160(tokenId_)));
        (uint256 amount0, uint256 amount1) = vault.totalUnderlying();
        IERC20Metadata token0 = IERC20Metadata(vault.token0());
        IERC20Metadata token1 = IERC20Metadata(vault.token1());

        return INFTSVG(_library).generateVaultURI(
            SVGParams({
                vault: address(vault),
                amount0: amount0,
                amount1: amount1,
                decimals0: token0.decimals(),
                decimals1: token1.decimals(),
                symbol0: token0.symbol(),
                symbol1: token1.symbol()
            })
        );

        // try INFTSVG(_library).generateVaultURI(
        //     SVGParams({
        //         vault: address(vault),
        //         amount0: amount0,
        //         amount1: amount1,
        //         decimals0: token0.decimals(),
        //         decimals1: token1.decimals(),
        //         symbol0: token0.symbol(),
        //         symbol1: token1.symbol()
        //     })
        // ) returns (string memory uri) {
        //     return uri;
        // } catch {
        //     return INFTSVG(_library).generateFallbackURI(
        //     SVGParams({
        //         vault: address(vault),
        //         amount0: amount0,
        //         amount1: amount1,
        //         decimals0: 0,
        //         decimals1: 0,
        //         symbol0: 'TKN0',
        //         symbol1: 'TKN1'
        //     })
        // );
        // }
    }
}
