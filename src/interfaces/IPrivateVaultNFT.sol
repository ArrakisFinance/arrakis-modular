// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPrivateVaultNFT {
    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external;

    // #region view functions.

    /// @dev for doing meta data calls of tokens.
    function getMetaDatas(
        address token0_,
        address token1_
    )
        external
        view
        returns (
            uint8 decimals0,
            uint8 decimals1,
            string memory symbol0,
            string memory symbol1
        );

    // #endregion view functions.
}
