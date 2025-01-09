// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IRFQWrapper} from "../interfaces/IRFQWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {RequestForQuote} from "../structs/SRequestForQuote.sol";
import {RFQHelper} from "../libraries/RFQHelper.sol";
import {PIPS, TEN_PERCENT} from "../constants/CArrakis.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {EIP712} from
    "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from
    "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract RFQWrapper is
    IRFQWrapper,
    Ownable,
    Pausable,
    EIP712,
    Initializable
{
    using RFQHelper for RequestForQuote;
    using RFQHelper for uint256;
    using SignatureChecker for address;
    using SafeCast for uint256;
    using SafeERC20 for IERC20Metadata;

    // #region immutable variables.

    address public immutable module;
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;
    uint8 public immutable decimals0;
    uint8 public immutable decimals1;
    IOracleWrapper public immutable oracle;

    // #endregion immutable variables.

    // #region internal immutable variable.

    address internal immutable _guardian;

    // #endregion internal immutable variable.

    // #region internal variables.

    uint256 internal _rfqState;
    uint256 internal _maxVolumeState;
    uint256 internal _internalState;

    // #endregion internal variables.

    // #region modifier.

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (msg.sender != pauser) {
            revert OnlyGuardian();
        }
        _;
    }

    // #endregion modifier.

    constructor(
        address guardian_,
        address owner_,
        address module_,
        address oracle_
    ) EIP712("RFQWrapper", "0.0.1") {
        if (
            guardian_ == address(0) || owner_ == address(0)
                || module_ == address(0) || oracle_ == address(0)
        ) {
            revert AddressZero();
        }

        _guardian = guardian_;
        module = module_;
        oracle = IOracleWrapper(oracle_);

        token0 = IArrakisLPModule(module_).token0();
        token1 = IArrakisLPModule(module_).token1();

        decimals0 = token0.decimals();
        decimals1 = token1.decimals();

        _initializeOwner(owner_);
    }

    function initialize(
        address signer_,
        uint128 maxToken0VolumeToQuote_,
        uint128 maxToken1VolumeToQuote_,
        uint32 maxDelay_,
        uint8 maxAllowedQuotes_,
        uint8 maxDeviation_
    ) external onlyOwner initializer {
        if (signer_ == address(0)) {
            revert AddressZero();
        }
        if (
            maxToken0VolumeToQuote_ == 0
                || maxToken1VolumeToQuote_ == 0
        ) {
            revert ZeroValue();
        }
        if (maxDelay_ == 0) {
            revert ZeroValue();
        }
        if (maxAllowedQuotes_ == 0) {
            revert ZeroValue();
        }
        if (maxDeviation_ == 0 || maxDeviation_ > TEN_PERCENT) {
            revert MaxDeviation();
        }

        _maxVolumeState = _maxVolumeState.setMaxToken0VolumeToQuote(
            maxToken0VolumeToQuote_
        ).setMaxToken1VolumeToQuote(maxToken1VolumeToQuote_);

        _internalState = _internalState.setSigner(signer_).setMaxDelay(
            maxDelay_
        ).setMaxAllowedQuotes(maxAllowedQuotes_).setMaxDeviation(
            maxDeviation_
        );
    }

    // #region pausable functions.

    /// @notice function used to pause the RFQWrapper.
    /// @dev only callable by guardian.
    function pause() external onlyGuardian {
        _pause();
    }

    /// @notice function used to unpause the RFQWrapper.
    /// @dev only callable by guardian.
    function unpause() external onlyGuardian {
        _unpause();
    }

    // #endregion pausable functions.

    // #region owner functions.

    function setSigner(
        address signer_
    ) external onlyOwner whenNotPaused {
        uint256 internalState = _internalState;
        address _signer = internalState.getSigner();

        if (signer_ == address(0)) {
            revert AddressZero();
        }
        if (_signer == signer_) {
            revert SameSigner();
        }

        _internalState = internalState.setSigner(signer_);

        emit LogSetSigner(_signer, signer_);
    }

    function setMaxAllowedQuotes(
        uint8 maxAllowedQuotes_
    ) external onlyOwner whenNotPaused {
        if (maxAllowedQuotes_ == 0) {
            revert ZeroValue();
        }
        _internalState =
            _internalState.setMaxAllowedQuotes(maxAllowedQuotes_);

        emit LogSetMaxAllowedQuotes(maxAllowedQuotes_);
    }

    function setMaxTokenVolumeToQuote(
        uint128 maxToken0VolumeToQuote_,
        uint128 maxToken1VolumeToQuote_
    ) external onlyOwner whenNotPaused {
        if (
            maxToken0VolumeToQuote_ == 0
                || maxToken1VolumeToQuote_ == 0
        ) {
            revert ZeroValue();
        }

        _maxVolumeState = _maxVolumeState.setMaxToken0VolumeToQuote(
            maxToken0VolumeToQuote_
        ).setMaxToken1VolumeToQuote(maxToken1VolumeToQuote_);

        emit LogSetMaxTokenVolumeToQuote(
            maxToken0VolumeToQuote_, maxToken1VolumeToQuote_
        );
    }

    function setMaxDelay(
        uint32 maxDelay_
    ) external onlyOwner whenNotPaused {
        if (maxDelay_ == 0) {
            revert ZeroValue();
        }

        _internalState = _internalState.setMaxDelay(maxDelay_);

        emit LogSetMaxDelay(maxDelay_);
    }

    function setMaxDeviation(
        uint8 maxDeviation_
    ) external onlyOwner whenNotPaused {
        if (maxDeviation_ == 0 || maxDeviation_ > TEN_PERCENT) {
            revert MaxDeviation();
        }

        _internalState = _internalState.setMaxDeviation(maxDeviation_);

        emit LogSetMaxDeviation(maxDeviation_);
    }

    // #endregion owner functions.

    function rfqSwap(
        RequestForQuote calldata params_,
        bytes calldata signature_
    ) external whenNotPaused {
        uint256 rfqState = _rfqState;
        uint256 internalState = _internalState;
        uint256 maxVolumeState = _maxVolumeState;
        uint32 blockTimestamp = block.timestamp.toUint32();

        // #region checks.

        // #region check rfqwrapper.

        if (params_.rfqwrapper != address(this)) {
            revert WrongRFQWrapper();
        }

        // #endregion check rfqwrapper.

        // #region verify signature.

        bytes32 quoteHash = params_.hashRequestForQuote();

        if (
            !internalState.getSigner().isValidSignatureNow(
                _hashTypedDataV4(quoteHash), signature_
            )
        ) {
            revert NotValidSignature();
        }

        // #endregion verify signature.

        // #region check authorization.

        if (params_.authorizedSender != msg.sender) {
            revert NotAuthorized();
        }

        // #endregion check authorization.

        // #region number of quotes.

        uint8 quotesInCurrentBlock = blockTimestamp
            > rfqState.getLastProcessedQuoteTimestamp()
            ? 1
            : rfqState.getLastProcessedBlockQuoteCount() + 1;

        if (
            quotesInCurrentBlock > internalState.getMaxAllowedQuotes()
        ) {
            revert MaxQuotesExceeded();
        }

        // #endregion number of quotes.

        // #region maximum volume.

        if (params_.zeroForOne) {
            if (
                params_.amountOut
                    > maxVolumeState.getMaxToken0VolumeToQuote()
            ) {
                revert MaximumVolumeOut();
            }
        } else {
            if (
                params_.amountOut
                    > maxVolumeState.getMaxToken1VolumeToQuote()
            ) {
                revert MaximumVolumeOut();
            }
        }

        // #endregion maximum volume.

        // #region check timestamp.

        if (params_.signatureTimestamp > blockTimestamp) {
            revert InvalidSignatureTimestamp();
        }
        if (
            blockTimestamp
                > params_.signatureTimestamp + params_.expiry
        ) revert QuoteExpired();
        if (params_.expiry > internalState.getMaxDelay()) {
            revert InvalidExpiry();
        }

        // #endregion check timestamp.

        // #region check nonce.

        uint56 bitmap = _rfqState.getBitMap();

        if (
            !_isNonceNotUsed(
                params_.nonce, params_.expectedFlag, bitmap
            )
        ) {
            revert InvalidNonce();
        }

        // #endregion check nonce.

        // #region check price.

        {
            uint256 quotePrice;
            uint256 oraclePrice;
            if (params_.zeroForOne) {
                quotePrice = FullMath.mulDiv(
                    params_.amountOut,
                    10 ** decimals0,
                    params_.amountIn
                );

                oraclePrice = oracle.getPrice0();
            } else {
                quotePrice = FullMath.mulDiv(
                    params_.amountOut,
                    10 ** decimals1,
                    params_.amountIn
                );

                oraclePrice = oracle.getPrice1();
            }

            uint256 deviation = quotePrice > oraclePrice
                ? FullMath.mulDiv(
                    quotePrice - oraclePrice, PIPS, oraclePrice
                )
                : FullMath.mulDiv(
                    oraclePrice - quotePrice, PIPS, oraclePrice
                );
            if (deviation > internalState.getMaxDeviation()) {
                revert QuotePriceDeviation();
            }
        }

        // #endregion check price.

        // #endregion checks.

        // #region effects.

        _rfqState = RFQHelper.setRfqState(
            _updateBitmap(params_.nonce, bitmap),
            blockTimestamp,
            quotesInCurrentBlock
        );

        // #endregion effects.

        // #region interactions.

        if (params_.zeroForOne) {
            token0.safeTransferFrom(
                params_.authorizedSender,
                module,
                params_.amountIn + params_.fee
            );

            token1.safeTransferFrom(
                module, params_.authorizedRecipient, params_.amountOut
            );
        } else {
            token1.safeTransferFrom(
                params_.authorizedSender,
                module,
                params_.amountIn + params_.fee
            );

            token0.safeTransferFrom(
                module, params_.authorizedRecipient, params_.amountOut
            );
        }

        // #endregion interactions.

        // #region events.

        // emit LogRFQSwap(
        //     params_.rfqwrapper,
        //     params_.authorizedSender,
        //     params_.authorizedRecipient,
        //     params_.amountIn,
        //     params_.amountOut,
        //     params_.fee,
        //     params_.signatureTimestamp,
        //     params_.expiry,
        //     params_.nonce,
        //     params_.expectedFlag,
        //     params_.isZeroToOne
        // );

        // #endregion events.
    }

    // #region view functions.

    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    function signer() external view returns (address) {
        return _internalState.getSigner();
    }

    function maxToken0VolumeToQuote()
        external
        view
        returns (uint128)
    {
        return uint128(_maxVolumeState.getMaxToken0VolumeToQuote());
    }

    function maxToken1VolumeToQuote()
        external
        view
        returns (uint128)
    {
        return uint128(_maxVolumeState.getMaxToken1VolumeToQuote());
    }

    function maxDelay() external view returns (uint32) {
        return _internalState.getMaxDelay();
    }

    function maxAllowedQuotes() external view returns (uint8) {
        return _internalState.getMaxAllowedQuotes();
    }

    function maxDeviation() external view returns (uint8) {
        return _internalState.getMaxDeviation();
    }

    // #endregion view functions.

    // #region view internal functions.

    function _isNonceNotUsed(
        uint8 nonce_,
        uint8 flag_,
        uint56 bitmap_
    ) internal pure returns (bool) {
        if (nonce_ > 55) {
            revert InvalidNonce();
        }
        if (flag_ > 1) {
            revert InvalidFlag();
        }

        return ((bitmap_ >> nonce_) & 1) == flag_;
    }

    function _updateBitmap(
        uint8 nonce_,
        uint56 bitmap_
    ) internal pure returns (uint56) {
        if (nonce_ > 55) {
            revert InvalidNonce();
        }

        return (bitmap_ ^ (1 << nonce_)).toUint56();
    }

    // #endregion view internal functions.
}
