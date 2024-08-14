// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IRenderController {
    // #region errors.

    error InvalidRenderer();
    error AddressZero();

    // #endregion errors.

    event LogSetRenderer(address newRenderer);

    // #region functions.

    /// @notice function used to set the renderer contract adress
    /// @dev only the owner can do it.
    /// @param renderer_ address of the contract that will
    /// render the tokenUri for the svg of the nft.
    function setRenderer(address renderer_) external;

    // #endregion functions.

    // #region view functions.

    /// @dev for knowning if renderer is a NFTSVG contract.
    function isNFTSVG(address renderer_)
        external
        view
        returns (bool);

    /// @notice NFTSVG contract that will generate the tokenURI.
    function renderer() external view returns (address);

    // #endregion view functions.
}
