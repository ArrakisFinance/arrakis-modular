// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {RequestForQuote} from "src/structs/SRequestForQuote.sol";

interface IRFQWrapper {
    // #region errors.

    error AddressZero();
    error SameModule();
    error OnlyGuardian();
    error SameSigner();
    error NotValidSignature();
    error ZeroValue();
    error MaxQuotesExceeded();
    error NotAuthorized();
    error MaximumVolumeOut();
    error InvalidSignatureTimestamp();
    error QuoteExpired();
    error InvalidNonce();
    error InvalidFlag();
    error InvalidExpiry();
    error WrongRFQWrapper();
    error QuotePriceDeviation();
    error MaxDeviation();

    // #endregion errors.

    // #region events.

    event LogSetModule(address oldModule, address newModule);
    event LogSetSigner(address oldSigner, address newSigner);
    event LogSetMaxAllowedQuotes(uint8 newMaxAllowedQuotes);
    event LogRFQSwap(
        address indexed rfqwrapper,
        address indexed authorizedSender,
        address indexed authorizedRecipient,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee,
        uint32 signatureTimestamp,
        uint32 expiry,
        uint8 nonce,
        uint8 expectedFlag,
        bool isZeroToOne
    );
    event LogSetMaxTokenVolumeToQuote(
        uint128 maxToken0VolumeToQuote, uint128 maxToken1VolumeToQuote
    );
    event LogSetMaxDelay(uint32 maxDelay);
    event LogSetMaxDeviation(uint24 maxDeviation);

    // #endregion events.

    function setSigner(
        address signer_
    ) external;
    function setMaxTokenVolumeToQuote(
        uint128 maxToken0VolumeToQuote_,
        uint128 maxToken1VolumeToQuote_
    ) external;
    function setMaxDelay(
        uint32 maxDelay_
    ) external;
    function setMaxAllowedQuotes(
        uint8 maxAllowedQuotes_
    ) external;
    function setMaxDeviation(
        uint24 maxDeviation_
    ) external;
    function rfqSwap(
        RequestForQuote calldata params_,
        bytes calldata signature_
    ) external;

    // #region view public functions.

    function signer() external view returns (address);
    function guardian() external view returns (address);
    function module() external view returns (address);
    function maxToken0VolumeToQuote()
        external
        view
        returns (uint128);
    function maxToken1VolumeToQuote()
        external
        view
        returns (uint128);
    function maxDelay() external view returns (uint32);
    function maxAllowedQuotes() external view returns (uint8);
    function maxDeviation() external view returns (uint24);

    // #endregion view public functions.
}
