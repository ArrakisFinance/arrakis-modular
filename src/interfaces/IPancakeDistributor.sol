// SPDX-License-Identifier: MIT
// Copyright (C) 2024 PancakeSwap
pragma solidity ^0.8.19;

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
