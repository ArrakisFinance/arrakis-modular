// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

uint24 constant PIPS = 1_000_000;
uint24 constant TEN_PERCENT = 100_000;
/// @dev keccak256(abi.encode("ERC20TYPE"))
bytes32 constant ERC20TYPE = 0x622455176864f807122afa6d289a279f65cb874aa288df301854eb10e461c66f;
/// @dev keccak256(abi.encode("NFTTYPE"))
bytes32 constant NFTTYPE = 0xc4d0d2f21a055d9d9ecb61b5b7ced1d77b855e43ca9459036f8dea463b825180;