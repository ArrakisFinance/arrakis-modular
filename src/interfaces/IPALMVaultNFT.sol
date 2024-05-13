// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IPALMVaultNFT {
    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external;
}
