// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

struct RequestForQuote {
    uint256 amountIn;
    uint256 amountOut;
    uint256 fee;
    address rfqwrapper;
    address authorizedSender;
    address authorizedRecipient;
    uint32 signatureTimestamp;
    uint32 expiry;
    uint8 nonce;
    uint8 expectedFlag;
    bool zeroForOne;
}
