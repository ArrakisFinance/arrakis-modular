// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/// @title Gnosis Protocol v2 Interaction Library
/// @author Gnosis Developers
library GPv2Interaction {
    struct Data {
        address target;
        uint256 value;
        bytes callData;
    }
}