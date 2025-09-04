// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IPancakeDistributor {
    /// @notice Parameters for claiming rewards
    struct ClaimParams {
        address token;
        uint256 amount;
        bytes32[] proof;
    }

    struct ClaimEscrowed {
        address token;
        uint256 amount;
    }

    /// @notice Allows users to claim their rewards
    /// @param claimParams An array of claim parameters
    function claim(
        ClaimParams[] calldata claimParams
    ) external;
}
