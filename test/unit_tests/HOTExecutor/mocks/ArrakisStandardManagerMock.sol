// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract ArrakisStandardManagerMock {
    function rebalance(
        address vault_,
        bytes[] calldata payloads_
    ) external {}

    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external {}
}
