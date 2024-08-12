// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IPrivateVaultNFT {
    // #region errors.

    error OnlyAnnouncer();
    error InvalidRenderer();
    error AddressZero();

    // #endregion errors.

    // #region events.

    event LogSetRenderer(address newRenderer);
    event LogAnnouncer(address announcer);

    // #endregion events.

    /// @notice function used to mint nft (representing a vault) and send it.
    /// @param to_ address where to send the NFT.
    /// @param tokenId_ id of the NFT to mint.
    function mint(address to_, uint256 tokenId_) external;

    /// @notice function used to set announcer.
    /// @param announcer_ address that will announce the renderer.
    function initialize(address announcer_) external;

    /// @notice function used to set the renderer contract
    /// @dev only the announcer can do it.
    /// @param renderer_ address of the contract that will
    /// render the tokenUri for the svg of the nft.
    function setRenderer(address renderer_) external;

    // #region view functions.

    /// @notice address that will announce the renderer.
    function announcer() external view returns (address);

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

    /// @dev for knowning if renderer is a NFTSVG contract.
    function isNFTSVG(address renderer_)
        external
        view
        returns (bool);

    // #endregion view functions.
}
