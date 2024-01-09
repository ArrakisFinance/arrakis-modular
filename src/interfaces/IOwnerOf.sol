// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IOwnerOf {
    function ownerOf(address vault_) external view returns(address);
}