// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ICreationCode {
    function getCreationCode() external view returns(bytes memory);
}