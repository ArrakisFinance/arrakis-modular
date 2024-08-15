// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface ICreationCode {
    function getCreationCode() external pure returns (bytes memory);
}
