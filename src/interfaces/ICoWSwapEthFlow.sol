// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EthFlowData} from "../structs/SCowswap.sol";

interface ICowSwapEthFlow {
    function createOrder(EthFlowData calldata order)
        external
        payable
        returns (bytes32 orderHash);

    function invalidateOrder(EthFlowData calldata order) external;
}