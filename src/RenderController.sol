// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {INFTSVG} from "src/utils/NFTSVG.sol";
import {IRenderController} from "./interfaces/IRenderController.sol";

import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract RenderController is
    Ownable,
    IRenderController,
    Initializable
{
    address public renderer;

    function initialize(address owner_) external initializer {
        if (owner_ == address(0)) {
            revert AddressZero();
        }

        _initializeOwner(owner_);
    }

    /// @notice function used to set the renderer contract
    /// @dev only the svgController can do it.
    /// @param renderer_ address of the contract that will
    /// render the tokenUri for the svg of the nft.
    function setRenderer(address renderer_) external onlyOwner {
        bool _isNftSvg;
        try this.isNFTSVG(renderer_) returns (bool isNs) {
            _isNftSvg = isNs;
        } catch {
            _isNftSvg = false;
        }
        if (!_isNftSvg) revert InvalidRenderer();
        renderer = renderer_;

        emit LogSetRenderer(renderer_);
    }

    function isNFTSVG(address renderer_) public view returns (bool) {
        return INFTSVG(renderer_).isNFTSVG();
    }
}
