// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {IBuilderHook} from "../interfaces/IBuilderHook.sol";
import {IUniV4BlockBuilder} from
    "../interfaces/IUniV4BlockBuilder.sol";
import {PermissionHook} from "./PermissionHook.sol";
import {Deal} from "../structs/SBuilder.sol";
import {BuilderDeal} from "../libraries/BuilderDeal.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {BalanceDelta} from
    "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDeltaLibrary} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {BeforeSwapDelta} from
    "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {EIP712} from
    "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {SignatureChecker} from
    "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {console} from "forge-std/console.sol";

// solhint-disable-next-line max-states-count
contract BuilderHook is
    IBuilderHook,
    EIP712,
    Ownable,
    Initializable,
    PermissionHook
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using BuilderDeal for Deal;
    using SignatureChecker for address;
    using SafeERC20 for IERC20;
    using Address for address payable;
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    address public immutable signer;
    IPoolManager public immutable poolManager;
    uint24 public immutable fee;

    PoolKey internal _poolKey;
    EnumerableSet.AddressSet internal _collaterals;

    // #region public properties.

    bytes32 public payloadHash;
    uint256 public blockHeight;
    uint256 public fees0;
    uint256 public fees1;
    mapping(bytes32 => bool) public isFeeFreeSwapHappened;

    // #endregion public properties.

    // #region modifier.

    modifier onlyPoolManager() {
        if (msg.sender != address(poolManager)) {
            revert OnlyPoolManager();
        }
        _;
    }

    modifier onlyCurrentBlock(Deal memory deal_) {
        if (deal_.blockHeight != block.number) {
            revert NotSameBlockHeight();
        }
        _;
    }

    // #endregion modifier.

    constructor(
        address module_,
        address signer_,
        address poolManager_,
        uint24 fee_
    ) PermissionHook(module_) EIP712("Builder Hook", "version 1") {
        if (signer_ == address(0) || poolManager_ == address(0)) {
            revert AddressZero();
        }

        if (fee_ == 0) {
            revert FeeZero();
        }

        signer = signer_;
        poolManager = IPoolManager(poolManager_);
        fee = fee_;
    }

    function initialize(address owner_) external initializer {
        if (owner_ == address(0)) {
            revert AddressZero();
        }

        _initializeOwner(owner_);
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function openPool(
        Deal calldata deal_,
        bytes calldata signature_
    ) external payable onlyCurrentBlock(deal_) {
        // #region onlyCaller.

        if (deal_.caller != msg.sender) {
            revert OnlyCaller();
        }

        // #endregion onlyCaller.

        // #region check that the pool is closed.

        if (deal_.blockHeight <= blockHeight) {
            revert CannotReOpenThePool();
        }

        if (deal_.blockHeight != block.number) {
            revert NotSameBlockHeight();
        }

        // #endregion check that the pool is closed.

        // #region check if the collateral is whitelisted.

        if (!_collaterals.contains(deal_.collateralToken)) {
            revert NotACollateral();
        }

        // #endregion check if the collateral is whitelisted.

        // #region verify the signature.

        bytes32 dealHash = deal_.hashDeal();

        if (
            !signer.isValidSignatureNow(
                _hashTypedDataV4(dealHash), signature_
            )
        ) {
            revert NotValidSignature();
        }

        // #endregion verify the signature.

        // #region get the collateral.

        uint256 amountToTransfer = deal_.collateralAmount + deal_.tips;

        if (amountToTransfer > 0) {
            if (
                deal_.collateralToken == NATIVE_COIN
                    && msg.value < amountToTransfer
            ) {
                revert NotEnoughNativeCoinSent();
            } else if (deal_.collateralToken != NATIVE_COIN) {
                IERC20(deal_.collateralToken).safeTransferFrom(
                    msg.sender, address(this), amountToTransfer
                );
            }
        }

        // #endregion get the collateral.

        // #region get pool state.

        (,, fees0, fees1) =
            IUniV4BlockBuilder(module).getAmountsAndFees();

        // #endregion get pool state.

        // #region store the hash for closing the pool.

        payloadHash = dealHash;
        blockHeight = block.number;

        // #endregion store the hash for closing the pool.

        emit OpenPool(deal_, signature_);
    }

    // solhint-disable-next-line function-max-lines, code-complexity
    function closePool(
        Deal calldata deal_,
        address receiver_
    ) external onlyCurrentBlock(deal_) {
        // #region onlyCaller.

        if (deal_.caller != msg.sender) {
            revert OnlyCaller();
        }

        // #endregion onlyCaller.

        bytes32 dealHash = deal_.hashDeal();

        if (dealHash != payloadHash) {
            revert NotRightDeal();
        }

        // #region get pool state.

        (uint256 amount0, uint256 amount1, uint256 f0, uint256 f1) =
            IUniV4BlockBuilder(module).getAmountsAndFees();

        if (
            f0 < fees0 + deal_.feeGeneration0
                || f1 < fees1 + deal_.feeGeneration1
        ) {
            revert NotEnoughFeeGenerated();
        }

        if (
            amount0 != deal_.finalAmount0
                || amount1 != deal_.finalAmount1
        ) {
            revert WrongFinalState();
        }

        PoolId poolId = _poolKey.toId();

        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolId);

        if (sqrtPriceX96 != deal_.finalSqrtPriceX96) {
            revert WrongFinalSqrtPrice();
        }

        // #endregion get pool state.

        // #region send back token to receiver.

        if (deal_.collateralToken == NATIVE_COIN) {
            payable(receiver_).sendValue(deal_.collateralAmount);
        } else {
            IERC20(deal_.collateralToken).safeTransfer(
                receiver_, deal_.collateralAmount
            );
        }

        // #endregion send back token to receiver.

        // #region free storage.

        payloadHash = bytes32(0);
        fees0 = 0;
        fees1 = 0;

        // #endregion free storage.

        emit ClosePool(deal_, receiver_);
    }

    function whitelistCollaterals(address[] calldata collaterals_)
        external
        onlyOwner
    {
        uint256 length = collaterals_.length;

        for (uint256 i; i < length; i++) {
            address collateral = collaterals_[i];

            if (collateral == address(0)) revert AddressZero();
            if (_collaterals.contains(collateral)) {
                revert AlreadyWhitelistedCollateral(collateral);
            }

            _collaterals.add(collateral);
        }

        emit LogWhitelistCollateral(collaterals_);
    }

    function blacklistCollaterals(address[] calldata collaterals_)
        external
        onlyOwner
    {
        uint256 length = collaterals_.length;

        for (uint256 i; i < length; i++) {
            address collateral = collaterals_[i];

            if (!_collaterals.contains(collateral)) {
                revert NotAlreadyACollateral(collateral);
            }

            _collaterals.remove(collateral);
        }

        emit LogBlacklistCollateral(collaterals_);
    }

    function getTokens(
        address token_,
        address receiver_
    ) external onlyOwner returns (uint256 amount) {
        // #region check if token is address(0).

        if (token_ == address(0) || receiver_ == address(0)) {
            revert AddressZero();
        }

        // #endregion check if token is address(0).

        if (token_ == NATIVE_COIN) {
            amount = address(this).balance;
            payable(receiver_).sendValue(amount);
        } else {
            amount = IERC20(token_).balanceOf(address(this));
            IERC20(token_).safeTransfer(receiver_, amount);
        }

        emit GetTokens(token_, receiver_);
    }

    // #region hooks.

    function afterInitialize(
        address,
        PoolKey calldata key,
        uint160,
        int24,
        bytes calldata
    ) external override returns (bytes4) {
        if (
            Currency.unwrap(_poolKey.currency0) != address(0)
                || Currency.unwrap(_poolKey.currency1) != address(0)
        ) {
            revert OnlyPool();
        }

        PoolId poolId = key.toId();
        (uint160 sqrtPriceX96,,,) =
            IPoolManager(poolManager).getSlot0(poolId);

        if (sqrtPriceX96 == 0) revert SqrtPriceZero();

        // #region check if poolKey fee is equal to builder hook fee.

        poolManager.updateDynamicLPFee(key, fee);

        // #endregion check if poolKey fee is equal to builder hook fee.

        _poolKey = key;
        return IHooks.afterInitialize.selector;
    }

    /// @notice The hook called before a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return BeforeSwapDelta The hook's delta in specified and unspecified currencies. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    /// @return uint24 Optionally override the lp fee, only used if three conditions are met: 1) the Pool has a dynamic fee, 2) the value's leading bit is set to 1 (24th bit, 0x800000), 3) the value is less than or equal to the maximum fee (1 million)
    // solhint-disable-next-line function-max-lines, code-complexity
    function beforeSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        bytes calldata hookData
    )
        external
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        /// @dev pool not open by block builder.
        if (payloadHash == bytes32(0)) {
            revert PoolNotOpen();
        }

        if (hookData.length == 0) {
            return (
                IHooks.beforeSwap.selector,
                BeforeSwapDeltaLibrary.ZERO_DELTA,
                0
            );
        }
        (Deal memory deal) = abi.decode(hookData, (Deal));

        bytes32 dealHash = deal.hashDeal();
        if (dealHash != payloadHash) {
            revert NotRightDeal();
        }

        if (isFeeFreeSwapHappened[dealHash]) {
            revert FeeFreeSwapHappened();
        }

        if (sender != deal.feeFreeSwapper) {
            return (
                IHooks.beforeSwap.selector,
                BeforeSwapDeltaLibrary.ZERO_DELTA,
                0
            );
        }

        // #region check that signed block number is current block.

        if (deal.blockHeight != block.number) {
            revert NotSameBlockHeight();
        }

        // #endregion check that signed block number is current block.

        poolManager.updateDynamicLPFee(_poolKey, 0);
        isFeeFreeSwapHappened[dealHash] = true;

        return (
            IHooks.beforeSwap.selector,
            BeforeSwapDeltaLibrary.ZERO_DELTA,
            0
        );
    }

    /// @notice The hook called after a swap
    /// @param sender The initial msg.sender for the swap call
    /// @param hookData Arbitrary data handed into the PoolManager by the swapper to be be passed on to the hook
    /// @return bytes4 The function selector for the hook
    /// @return int128 The hook's delta in unspecified currency. Positive: the hook is owed/took currency, negative: the hook owes/sent currency
    function afterSwap(
        address sender,
        PoolKey calldata,
        IPoolManager.SwapParams calldata,
        BalanceDelta,
        bytes calldata hookData
    ) external override onlyPoolManager returns (bytes4, int128) {
        if (hookData.length == 0) {
            return (IHooks.afterSwap.selector, 0);
        }
        (Deal memory deal) = abi.decode(hookData, (Deal));

        if (sender != deal.feeFreeSwapper) {
            revert NotFeeFreeSwapper();
        }

        poolManager.updateDynamicLPFee(_poolKey, fee);

        return (IHooks.afterSwap.selector, 0);
    }

    // #endregion hooks.

    // #region view functions.

    function collaterals() external view returns (address[] memory) {
        return _collaterals.values();
    }

    // #endregion view functions.
}
