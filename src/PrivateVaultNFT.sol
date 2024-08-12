// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {INFTSVG, SVGParams} from "src/utils/NFTSVG.sol";
import {IPrivateVaultNFT} from "./interfaces/IPrivateVaultNFT.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract PrivateVaultNFT is
    Ownable,
    ERC721,
    Initializable,
    IPrivateVaultNFT
{
    address private _renderer;
    address public svgController;

    constructor() ERC721("Arrakis Private LP NFT", "ARRAKIS") {
        _initializeOwner(msg.sender);
    }

    function initialize(address svgController_) external initializer {
        if (svgController_ == address(0)) {
            revert AddressZero();
        }
        svgController = svgController_;

        emit LogSvgController(svgController_);
    }

    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external onlyOwner {
        _safeMint(to_, tokenId_);
    }

    /// @notice function used to set the renderer contract
    /// @dev only the svgController can do it.
    /// @param renderer_ address of the contract that will
    /// render the tokenUri for the svg of the nft.
    function setRenderer(address renderer_) external {
        if (msg.sender != svgController) {
            revert OnlySvgController();
        }
        bool _isNftSvg;
        try this.isNFTSVG(renderer_) returns (bool isNs) {
            _isNftSvg = isNs;
        } catch {
            _isNftSvg = false;
        }
        if (!_isNftSvg) revert InvalidRenderer();
        _renderer = renderer_;

        emit LogSetRenderer(renderer_);
    }

    function tokenURI(uint256 tokenId_)
        public
        view
        override
        returns (string memory)
    {
        IArrakisMetaVault vault =
            IArrakisMetaVault(address(uint160(tokenId_)));
        (uint256 amount0, uint256 amount1) = vault.totalUnderlying();

        try this.getMetaDatas(vault.token0(), vault.token1())
        returns (
            uint8 decimals0,
            uint8 decimals1,
            string memory symbol0,
            string memory symbol1
        ) {
            return INFTSVG(_renderer).generateVaultURI(
                SVGParams({
                    vault: address(vault),
                    amount0: amount0,
                    amount1: amount1,
                    decimals0: decimals0,
                    decimals1: decimals1,
                    symbol0: symbol0,
                    symbol1: symbol1
                })
            );
        } catch {
            return INFTSVG(_renderer).generateFallbackURI(
                SVGParams({
                    vault: address(vault),
                    amount0: amount0,
                    amount1: amount1,
                    decimals0: 4,
                    decimals1: 4,
                    symbol0: "TKN0",
                    symbol1: "TKN1"
                })
            );
        }
    }

    function getMetaDatas(
        address token0_,
        address token1_
    )
        public
        view
        returns (
            uint8 decimals0,
            uint8 decimals1,
            string memory symbol0,
            string memory symbol1
        )
    {
        decimals0 = IERC20Metadata(token0_).decimals();
        decimals1 = IERC20Metadata(token1_).decimals();
        symbol0 = IERC20Metadata(token0_).symbol();
        symbol1 = IERC20Metadata(token1_).symbol();
    }

    function isNFTSVG(address renderer_) public view returns (bool) {
        return INFTSVG(renderer_).isNFTSVG();
    }
}
