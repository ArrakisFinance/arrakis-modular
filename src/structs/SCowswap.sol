// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "../interfaces/ICowSwapERC20.sol";

/// @dev taken from https://github.com/cowprotocol/contracts/blob/c15d99a146c8aa428a7fea3167c2f3d933b8f7fd/src/contracts/libraries/GPv2Order.sol#L11-L24
struct Data {
    IERC20 sellToken;
    IERC20 buyToken;
    address receiver;
    uint256 sellAmount;
    uint256 buyAmount;
    uint32 validTo;
    bytes32 appData;
    uint256 feeAmount;
    bytes32 kind;
    bool partiallyFillable;
    bytes32 sellTokenBalance;
    bytes32 buyTokenBalance;
}

/// @dev taken from https://github.com/cowprotocol/ethflowcontract/blob/f466b7a8d5df80b593aeb05488e1c27afc7f2704/src/libraries/EthFlowOrder.sol#L19-L45
struct EthFlowData {
    IERC20 buyToken;
    address receiver;
    uint256 sellAmount;
    uint256 buyAmount;
    bytes32 appData;
    uint256 feeAmount;
    uint32 validTo;
    bool partiallyFillable;
    int64 quoteId;
}

struct SignatureData {
    uint256 signedTimestamp;
    uint256 nonce;
    bytes32 orderHash;
    bytes order;
    bytes signature;
}
