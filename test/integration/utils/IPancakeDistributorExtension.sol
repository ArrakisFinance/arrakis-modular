// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

interface IPancakeDistributor {
    /// @notice Parameters for claiming rewards
    struct ClaimParams {
        address token;
        uint256 amount;
        bytes32[] proof;
    }

    /// @notice Allows users to claim their rewards
    /// @param claimParams An array of claim parameters
    function claim(
        ClaimParams[] calldata claimParams
    ) external;
}

interface IPancakeDistributorExtension is IPancakeDistributor {
    function setMerkleTree(bytes32 root, bytes32 ipfsHash) external;

    function merkleTreeRoot() external view returns (bytes32);

    function claimedAmounts(address token, address user) external view returns (uint256);

    function disputer() external view returns (address);

    function getMerkleTreeRoot() external view returns (bytes32);

    function endOfDisputePeriod() external view returns (uint256);
}
