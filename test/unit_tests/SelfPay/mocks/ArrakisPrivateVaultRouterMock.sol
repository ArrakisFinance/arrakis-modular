// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

contract ArrakisPrivateVaultRouterMock {
    function test() external {}

    function failTest() external pure {
        revert();
    }
}
