// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

uint24 constant PIPS = 1_000_000;
uint24 constant TEN_PERCENT = 100_000;
/// @dev keccak256(abi.encode("PUBLIC"))
bytes32 constant PUBLIC_TYPE = 0x6c9260317eb3686591d0f7f822e48f62c94ad687bd13b2e0d60b2fd97500094a;
/// @dev keccak256(abi.encode("PRIVATE"))
bytes32 constant PRIVATE_TYPE = 0x328c5974909fb30f82b805e5f612684a346fe6c97f65297e727160ed87c33a19;