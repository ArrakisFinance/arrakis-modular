// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {RequestForQuote} from "../structs/SRequestForQuote.sol";

library RFQHelper {
    bytes32 constant RFQ_EIP712HASH = keccak256(
        "RequestForQuote(uint256 amountIn,uint256 amountOut,address module,address authorizedSender,address authorizedRecipient,uint32 signatureTimestamp,uint32 expiry,uint8 nonce,uint8 expectedFlag,bool isZeroToOne)"
    );

    function hashRequestForQuote(
        RequestForQuote memory rfq_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encode(RFQ_EIP712HASH, rfq_));
    }

    // #region rfq state.

    function getBitMap(
        uint256 rfqState_
    ) internal pure returns (uint56 bitmap) {
        unchecked {
            bitmap = uint56(rfqState_);
        }
    }

    function getLastProcessedQuoteTimestamp(
        uint256 rfqState_
    ) internal pure returns (uint32 lastProcessedQuoteTimestamp) {
        unchecked {
            lastProcessedQuoteTimestamp =
                uint32(uint256(rfqState_ >> 56));
        }
    }

    function getLastProcessedBlockQuoteCount(
        uint256 rfqState_
    ) internal pure returns (uint8 lastProcessedBlockQuoteCount) {
        unchecked {
            lastProcessedBlockQuoteCount =
                uint8(uint256(rfqState_ >> 88));
        }
    }

    function setRfqState(
        uint56 bitmap_,
        uint32 lastProcessedQuoteTimestamp_,
        uint8 lastProcessedBlockQuoteCount_
    ) internal pure returns (uint256 rfqState) {
        unchecked {
            rfqState = uint256(bitmap_)
                | (uint256(lastProcessedQuoteTimestamp_) << 56)
                | (uint256(lastProcessedBlockQuoteCount_) << 88);
        }
    }

    // #endregion rfq state.

    // #region max volume state.

    function getMaxToken0VolumeToQuote(
        uint256 maxVolumeState_
    ) internal pure returns (uint128 maxToken0VolumeToQuote) {
        unchecked {
            maxToken0VolumeToQuote = uint128(maxVolumeState_);
        }
    }

    function getMaxToken1VolumeToQuote(
        uint256 maxVolumeState_
    ) internal pure returns (uint128 maxToken1VolumeToQuote) {
        unchecked {
            maxToken1VolumeToQuote =
                uint128(uint256(maxVolumeState_ >> 128));
        }
    }

    function setMaxToken0VolumeToQuote(
        uint256 maxVolumeState_,
        uint128 maxToken0VolumeToQuote_
    ) internal pure returns (uint256 maxVolumeState) {
        unchecked {
            maxVolumeState = uint256(maxToken0VolumeToQuote_)
                | (uint256(maxVolumeState_ >> 128) << 128);
        }
    }

    function setMaxToken1VolumeToQuote(
        uint256 maxVolumeState_,
        uint128 maxToken1VolumeToQuote_
    ) internal pure returns (uint256 maxVolumeState) {
        unchecked {
            maxVolumeState = uint256(uint128(maxVolumeState_))
                | (uint256(maxToken1VolumeToQuote_) << 128);
        }
    }

    // #endregion max volume state.

    // #region internal state.

    function getSigner(
        uint256 internalState_
    ) internal pure returns (address signer) {
        unchecked {
            signer = address(uint160(internalState_));
        }
    }

    function setSigner(
        uint256 internalState_,
        address signer_
    ) internal pure returns (uint256 internalState) {
        unchecked {
            internalState = uint256(uint160(signer_))
                | ((internalState_ >> 160) << 160);
        }
    }

    function getMaxDelay(
        uint256 internalState_
    ) internal pure returns (uint32 maxDelay) {
        unchecked {
            maxDelay = uint32(internalState_ >> 160);
        }
    }

    function setMaxDelay(
        uint256 internalState_,
        uint32 maxDelay_
    ) internal pure returns (uint256 internalState) {
        unchecked {
            internalState = uint256(uint160(internalState_))
                | (uint256(maxDelay_) << 160)
                | ((internalState_ >> 192) << 192);
        }
    }

    function getMaxDeviation(
        uint256 internalState_
    ) internal pure returns (uint24 maxDeviation) {
        unchecked {
            maxDeviation = uint24(internalState_ >> 192);
        }
    }

    function setMaxDeviation(
        uint256 internalState_,
        uint24 maxDeviation_
    ) internal pure returns (uint256 internalState) {
        unchecked {
            internalState = uint256((internalState_ << 64) >> 64)
                | (uint256(maxDeviation_) << 192)
                | ((internalState_ >> 216) << 216);
        }
    }

    function getMaxAllowedQuotes(
        uint256 internalState_
    ) internal pure returns (uint8 maxAllowedQuotes) {
        unchecked {
            maxAllowedQuotes = uint8(internalState_ >> 216);
        }
    }

    function setMaxAllowedQuotes(
        uint256 internalState_,
        uint8 maxAllowedQuotes_
    ) internal pure returns (uint256 internalState) {
        unchecked {
            internalState = uint256((internalState_ << 40) >> 40)
                | (uint256(maxAllowedQuotes_) << 216);
        }
    }

    // #endregion internal state.
}
