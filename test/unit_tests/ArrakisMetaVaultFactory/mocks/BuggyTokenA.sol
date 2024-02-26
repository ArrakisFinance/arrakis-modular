// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract BuggyTokenA {
    function symbol() external pure returns (string memory) {
        revert("Not Implemented");
    }
}
