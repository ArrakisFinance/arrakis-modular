// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Deal} from "../structs/SBuilder.sol";
import {DEAL_EIP712HASH} from "../constants/CBuilder.sol";

library BuilderDeal {
    function hashDeal(Deal memory deal_)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(DEAL_EIP712HASH, deal_));
    }
}
