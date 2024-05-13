// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {
    IArrakisPublicVaultRouter,
    AddLiquidityData,
    SwapAndAddData,
    RemoveLiquidityData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data,
    RemoveLiquidityPermit2Data
} from "./interfaces/IArrakisPublicVaultRouter.sol";
import {TokenPermissions} from "./structs/SPermit2.sol";
import {IArrakisMetaVaultFactory} from
    "./interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPublic} from
    "./interfaces/IArrakisMetaVaultPublic.sol";
import {IRouterSwapExecutor} from
    "./interfaces/IRouterSwapExecutor.sol";
import {
    IPermit2,
    SignatureTransferDetails
} from "./interfaces/IPermit2.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {BASE} from "./constants/CArrakis.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

// #region solady dependencies.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady dependencies.

contract ArrakisPublicVaultRouter is
    IArrakisPublicVaultRouter,
    ReentrancyGuard,
    Ownable,
    Pausable
{
    using Address for address payable;
    using SafeERC20 for IERC20;

    // #region immutable properties.

    address public immutable nativeToken;
    IPermit2 public immutable permit2;
    IArrakisMetaVaultFactory public immutable factory;
    IWETH9 public immutable weth;

    // #endregion immutable properties.

    IRouterSwapExecutor public swapper;

    // #region modifiers.

    modifier onlyPublicVault(address vault_) {
        if (!factory.isPublicVault(vault_)) revert OnlyPublicVault();
        _;
    }

    // #endregion modifiers.

    constructor(
        address nativeToken_,
        address permit2_,
        address owner_,
        address factory_,
        address weth_
    ) {
        if (
            nativeToken_ == address(0) || permit2_ == address(0)
                || owner_ == address(0) || factory_ == address(0)
                || weth_ == address(0)
        ) revert AddressZero();

        nativeToken = nativeToken_;
        permit2 = IPermit2(permit2_);
        _initializeOwner(owner_);
        factory = IArrakisMetaVaultFactory(factory_);
        weth = IWETH9(weth_);
    }

    // #region owner functions.

    /// @notice function used to pause the router.
    /// @dev only callable by owner
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice function used to unpause the router.
    /// @dev only callable by owner
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function updateSwapExecutor(address swapper_)
        external
        whenNotPaused
        onlyOwner
    {
        if (swapper_ == address(0)) revert AddressZero();
        swapper = IRouterSwapExecutor(swapper_);
    }

    // #endregion owner functions.

    /// @notice addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function addLiquidity(AddLiquidityData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        )
    {
        // #region checks.
        if (params_.amount0Max == 0 && params_.amount1Max == 0) {
            revert EmptyMaxAmounts();
        }

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.vault, params_.amount0Max, params_.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.amount0Min
                || amount1 < params_.amount1Min
                || sharesReceived < params_.amountSharesMin
        ) {
            revert BelowMinAmounts();
        }

        address token0 = IArrakisMetaVault(params_.vault).token0();
        address token1 = IArrakisMetaVault(params_.vault).token1();

        // #endregion checks.

        // #region interactions.

        if (token0 != nativeToken && amount0 > 0) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), amount0
            );
        }

        if (token1 != nativeToken && amount1 > 0) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), amount1
            );
        }

        _addLiquidity(
            params_.vault,
            amount0,
            amount1,
            sharesReceived,
            params_.receiver,
            token0,
            token1
        );

        if (msg.value > 0) {
            if (token0 == nativeToken && msg.value > amount0) {
                payable(msg.sender).sendValue(msg.value - amount0);
            } else if (token1 == nativeToken && msg.value > amount1) {
                payable(msg.sender).sendValue(msg.value - amount1);
            }
        }

        // #endregion interactions.
    }

    /// @notice swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        // #region checks.

        if (
            params_.addData.amount0Max == 0
                && params_.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        if (
            token0 == nativeToken && params_.addData.amount0Max > 0
                && msg.value != params_.addData.amount0Max
        ) {
            revert NotEnoughNativeTokenSent();
        }

        if (
            token1 == nativeToken && params_.addData.amount1Max > 0
                && msg.value != params_.addData.amount1Max
        ) {
            revert NotEnoughNativeTokenSent();
        }

        // #region interactions.

        if (params_.addData.amount0Max > 0 && token0 != nativeToken) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), params_.addData.amount0Max
            );
        }
        if (params_.addData.amount1Max > 0 && token1 != nativeToken) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), params_.addData.amount1Max
            );
        }

        // #endregion interactions.

        (amount0, amount1, sharesReceived, amount0Diff, amount1Diff) =
        _swapAndAddLiquiditySendBackLeftOver(params_, token0, token1);
    }

    /// @notice removeLiquidity removes liquidity from vault and burns LP tokens
    /// @param params_ RemoveLiquidityData struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidity(RemoveLiquidityData memory params_)
        external
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.vault)
        returns (uint256 amount0, uint256 amount1)
    {
        if (params_.burnAmount == 0) revert NothingToBurn();

        IERC20(params_.vault).safeTransferFrom(
            msg.sender, address(this), params_.burnAmount
        );

        (amount0, amount1) = _removeLiquidity(params_);
    }

    /// @notice addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        )
    {
        // #region checks.
        if (
            params_.addData.amount0Max == 0
                && params_.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.addData.vault,
            params_.addData.amount0Max,
            params_.addData.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.addData.amount0Min
                || amount1 < params_.addData.amount1Min
                || sharesReceived < params_.addData.amountSharesMin
        ) revert BelowMinAmounts();

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        _permit2AddLengthOneOrTwo(
            params_, token0, token1, amount0, amount1
        );

        _addLiquidity(
            params_.addData.vault,
            amount0,
            amount1,
            sharesReceived,
            params_.addData.receiver,
            token0,
            token1
        );
    }

    /// @notice swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.swapAndAddData.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        if (
            params_.swapAndAddData.addData.amount0Max == 0
                && params_.swapAndAddData.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        address token0 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token0();
        address token1 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token1();

        _permit2SwapAndAddLengthOneOrTwo(params_, token0, token1);

        (amount0, amount1, sharesReceived, amount0Diff, amount1Diff) =
        _swapAndAddLiquiditySendBackLeftOver(
            params_.swapAndAddData, token0, token1
        );
    }

    /// @notice removeLiquidityPermit2 removes liquidity from vault and burns LP tokens
    /// @param params_ RemoveLiquidityPermit2Data struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidityPermit2(
        RemoveLiquidityPermit2Data memory params_
    )
        external
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.removeData.vault)
        returns (uint256 amount0, uint256 amount1)
    {
        if (params_.removeData.burnAmount == 0) {
            revert NothingToBurn();
        }

        SignatureTransferDetails memory transferDetails =
        SignatureTransferDetails({
            to: address(this),
            requestedAmount: params_.removeData.burnAmount
        });
        permit2.permitTransferFrom(
            params_.permit,
            transferDetails,
            msg.sender,
            params_.signature
        );

        (amount0, amount1) = _removeLiquidity(params_.removeData);
    }

    /// @notice wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wrapAndAddLiquidity(AddLiquidityData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        )
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.

        // #region checks.
        if (params_.amount0Max == 0 && params_.amount1Max == 0) {
            revert EmptyMaxAmounts();
        }

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.vault, params_.amount0Max, params_.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.amount0Min
                || amount1 < params_.amount1Min
                || sharesReceived < params_.amountSharesMin
        ) {
            revert BelowMinAmounts();
        }

        address token0 = IArrakisMetaVault(params_.vault).token0();
        address token1 = IArrakisMetaVault(params_.vault).token1();

        if (token0 == nativeToken || token1 == nativeToken) {
            revert NativeTokenNotSupported();
        }
        if (token0 != address(weth) && token1 != address(weth)) {
            revert NoWethToken();
        }

        // #endregion checks.

        // #region interactions.

        if (token0 != address(weth) && amount0 > 0) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), amount0
            );
        }

        if (token1 != address(weth) && amount1 > 0) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), amount1
            );
        }

        _addLiquidity(
            params_.vault,
            amount0,
            amount1,
            sharesReceived,
            params_.receiver,
            token0,
            token1
        );

        if (token0 == address(weth) && msg.value > amount0) {
            weth.withdraw(msg.value - amount0);
            payable(msg.sender).sendValue(msg.value - amount0);
        } else if (token1 == address(weth) && msg.value > amount1) {
            weth.withdraw(msg.value - amount1);
            payable(msg.sender).sendValue(msg.value - amount1);
        }

        // #endregion interactions.
    }

    /// @notice wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.

        if (
            params_.addData.amount0Max == 0
                && params_.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        if (token0 == nativeToken || token1 == nativeToken) {
            revert NativeTokenNotSupported();
        }
        if (token0 != address(weth) && token1 != address(weth)) {
            revert NoWethToken();
        }

        // #region interactions.

        if (token0 != address(weth)) {
            if (params_.addData.amount0Max > 0) {
                IERC20(token0).safeTransferFrom(
                    msg.sender,
                    address(this),
                    params_.addData.amount0Max
                );
            }
        } else if (params_.addData.amount0Max != msg.value) {
            revert MsgValueDTMaxAmount();
        }
        if (token1 != address(weth)) {
            if (params_.addData.amount1Max > 0) {
                IERC20(token1).safeTransferFrom(
                    msg.sender,
                    address(this),
                    params_.addData.amount1Max
                );
            }
        } else if (params_.addData.amount1Max != msg.value) {
            revert MsgValueDTMaxAmount();
        }

        // #endregion interactions.
        (
            ,
            ,
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(params_, token0, token1);

        /// @dev hack to get rid of stack too depth
        uint256 amount0Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount0Max - amount0Diff
            : params_.addData.amount0Max + amount0Diff;
        uint256 amount1Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount1Max + amount1Diff
            : params_.addData.amount1Max - amount1Diff;

        if (amount0Use > amount0) {
            if (token0 == address(weth)) {
                weth.withdraw(amount0Use - amount0);
                payable(msg.sender).sendValue(amount0Use - amount0);
            } else {
                uint256 balance =
                    IERC20(token0).balanceOf(address(this));
                IERC20(token0).safeTransfer(msg.sender, balance);
            }
        }

        if (amount1Use > amount1) {
            if (token1 == address(weth)) {
                weth.withdraw(amount1Use - amount1);
                payable(msg.sender).sendValue(amount1Use - amount1);
            } else {
                uint256 balance =
                    IERC20(token1).balanceOf(address(this));
                IERC20(token1).safeTransfer(msg.sender, balance);
            }
        }
    }

    /// @notice wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wrapAndAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived
        )
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.
        if (
            params_.addData.amount0Max == 0
                && params_.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.addData.vault,
            params_.addData.amount0Max,
            params_.addData.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.addData.amount0Min
                || amount1 < params_.addData.amount1Min
                || sharesReceived < params_.addData.amountSharesMin
        ) revert BelowMinAmounts();

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        if (token0 == nativeToken || token1 == nativeToken) {
            revert NativeTokenNotSupported();
        }
        if (token0 != address(weth) && token1 != address(weth)) {
            revert NoWethToken();
        }

        // #endregion checks.

        _permit2AddLengthOne(
            params_, token0, token1, amount0, amount1
        );

        _addLiquidity(
            params_.addData.vault,
            amount0,
            amount1,
            sharesReceived,
            params_.addData.receiver,
            token0,
            token1
        );

        if (token0 == address(weth) && msg.value > amount0) {
            weth.withdraw(msg.value - amount0);
            payable(msg.sender).sendValue(msg.value - amount0);
        } else if (token1 == address(weth) && msg.value > amount1) {
            weth.withdraw(msg.value - amount1);
            payable(msg.sender).sendValue(msg.value - amount1);
        }
    }

    /// @notice wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.swapAndAddData.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        if (
            params_.swapAndAddData.addData.amount0Max == 0
                && params_.swapAndAddData.addData.amount1Max == 0
        ) {
            revert EmptyMaxAmounts();
        }

        address token0 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token0();
        address token1 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token1();

        if (token0 == nativeToken || token1 == nativeToken) {
            revert NativeTokenNotSupported();
        }
        if (token0 != address(weth) && token1 != address(weth)) {
            revert NoWethToken();
        }

        if (
            token0 == address(weth)
                && params_.swapAndAddData.addData.amount0Max != msg.value
        ) {
            revert MsgValueDTMaxAmount();
        }
        if (
            token1 == address(weth)
                && params_.swapAndAddData.addData.amount1Max != msg.value
        ) {
            revert MsgValueDTMaxAmount();
        }

        _permit2SwapAndAddLengthOne(params_, token0, token1);

        (
            ,
            ,
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(
            params_.swapAndAddData, token0, token1
        );

        /// @dev hack to get rid of stack too depth
        uint256 amount0Use = (
            params_.swapAndAddData.swapData.zeroForOne
        )
            ? params_.swapAndAddData.addData.amount0Max - amount0Diff
            : params_.swapAndAddData.addData.amount0Max + amount0Diff;
        uint256 amount1Use = (
            params_.swapAndAddData.swapData.zeroForOne
        )
            ? params_.swapAndAddData.addData.amount1Max + amount1Diff
            : params_.swapAndAddData.addData.amount1Max - amount1Diff;

        if (amount0Use > amount0) {
            if (token0 == address(weth)) {
                weth.withdraw(amount0Use - amount0);
                payable(msg.sender).sendValue(amount0Use - amount0);
            } else {
                uint256 balance =
                    IERC20(token0).balanceOf(address(this));
                IERC20(token0).safeTransfer(msg.sender, balance);
            }
        }

        if (amount1Use > amount1) {
            if (token1 == address(weth)) {
                weth.withdraw(amount1Use - amount1);
                payable(msg.sender).sendValue(amount1Use - amount1);
            } else {
                uint256 balance =
                    IERC20(token1).balanceOf(address(this));
                IERC20(token1).safeTransfer(msg.sender, balance);
            }
        }
    }

    receive() external payable {}

    // #region external view functions.

    /// @notice getMintAmounts used to get the shares we can mint from some max amounts.
    /// @param vault_ meta vault address.
    /// @param maxAmount0_ maximum amount of token0 user want to contribute.
    /// @param maxAmount1_ maximum amount of token1 user want to contribute.
    /// @return shareToMint maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.
    /// @return amount0ToDeposit amount of token0 user should deposit into the vault for minting 'shareToMint'.
    /// @return amount1ToDeposit amount of token1 user should deposit into the vault for minting 'shareToMint'.
    function getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        external
        view
        returns (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        )
    {
        return _getMintAmounts(vault_, maxAmount0_, maxAmount1_);
    }

    // #endregion external view functions.

    // #region internal functions.

    function _addLiquidity(
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
        uint256 shares_,
        address receiver_,
        address token0_,
        address token1_
    ) internal {
        address module = address(IArrakisMetaVault(vault_).module());

        uint256 valueToSend;
        uint256 balance0;
        uint256 balance1;
        if (token0_ != nativeToken) {
            IERC20(token0_).safeIncreaseAllowance(module, amount0_);
            balance0 = IERC20(token0_).balanceOf(address(this));
        } else {
            valueToSend = amount0_;
            balance0 = address(this).balance;
        }
        if (token1_ != nativeToken) {
            IERC20(token1_).safeIncreaseAllowance(module, amount1_);
            balance1 = IERC20(token1_).balanceOf(address(this));
        } else {
            valueToSend = amount1_;
            balance1 = address(this).balance;
        }

        IArrakisMetaVaultPublic(vault_).mint{value: valueToSend}(
            shares_, receiver_
        );
    }

    function _swapAndAddLiquidity(
        SwapAndAddData memory params_,
        address token0_,
        address token1_
    )
        internal
        returns (
            uint256 amount0Use,
            uint256 amount1Use,
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        uint256 valueToSend;
        if (params_.swapData.zeroForOne) {
            if (token0_ != nativeToken) {
                IERC20(token0_).safeTransfer(
                    address(swapper), params_.swapData.amountInSwap
                );
            } else {
                valueToSend = params_.swapData.amountInSwap;
            }
        } else {
            if (token1_ != nativeToken) {
                IERC20(token1_).safeTransfer(
                    address(swapper), params_.swapData.amountInSwap
                );
            } else {
                valueToSend = params_.swapData.amountInSwap;
            }
        }

        (amount0Diff, amount1Diff) =
            swapper.swap{value: valueToSend}(params_);

        emit Swapped(
            params_.swapData.zeroForOne,
            amount0Diff,
            amount1Diff,
            params_.swapData.amountOutSwap
        );

        amount0Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount0Max - amount0Diff
            : params_.addData.amount0Max + amount0Diff;
        amount1Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount1Max + amount1Diff
            : params_.addData.amount1Max - amount1Diff;

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.addData.vault, amount0Use, amount1Use
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.addData.amount0Min
                || amount1 < params_.addData.amount1Min
                || sharesReceived < params_.addData.amountSharesMin
        ) revert BelowMinAmounts();

        _addLiquidity(
            params_.addData.vault,
            amount0,
            amount1,
            sharesReceived,
            params_.addData.receiver,
            token0_,
            token1_
        );
    }

    function _swapAndAddLiquiditySendBackLeftOver(
        SwapAndAddData memory params_,
        address token0_,
        address token1_
    )
        internal
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        uint256 amount0Use;
        uint256 amount1Use;
        (
            amount0Use,
            amount1Use,
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(params_, token0_, token1_);

        if (amount0Use > amount0) {
            if (token0_ == nativeToken) {
                payable(msg.sender).sendValue(amount0Use - amount0);
            } else {
                uint256 balance =
                    IERC20(token0_).balanceOf(address(this));
                IERC20(token0_).safeTransfer(msg.sender, balance);
            }
        }

        if (amount1Use > amount1) {
            if (token1_ == nativeToken) {
                payable(msg.sender).sendValue(amount1Use - amount1);
            } else {
                uint256 balance =
                    IERC20(token1_).balanceOf(address(this));
                IERC20(token1_).safeTransfer(msg.sender, balance);
            }
        }
    }

    function _removeLiquidity(RemoveLiquidityData memory params_)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = IArrakisMetaVaultPublic(params_.vault)
            .burn(params_.burnAmount, params_.receiver);

        if (
            amount0 < params_.amount0Min
                || amount1 < params_.amount1Min
        ) {
            revert ReceivedBelowMinimum();
        }
    }

    function _permit2AddLengthOne(
        AddLiquidityPermit2Data memory params_,
        address token0_,
        address token1_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        uint256 permittedLength = params_.permit.permitted.length;
        if (permittedLength != 1) {
            revert LengthMismatch();
        }

        if (params_.permit.permitted[0].token == address(weth)) {
            revert Permit2WethNotAuthorized();
        }

        _permit2Add(
            permittedLength,
            params_,
            token0_,
            token1_,
            amount0_,
            amount1_
        );
    }

    function _permit2AddLengthOneOrTwo(
        AddLiquidityPermit2Data memory params_,
        address token0_,
        address token1_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        uint256 permittedLength = params_.permit.permitted.length;
        if (permittedLength != 2 && permittedLength != 1) {
            revert LengthMismatch();
        }

        _permit2Add(
            permittedLength,
            params_,
            token0_,
            token1_,
            amount0_,
            amount1_
        );
    }

    function _permit2Add(
        uint256 permittedLength_,
        AddLiquidityPermit2Data memory params_,
        address token0_,
        address token1_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        SignatureTransferDetails[] memory transfers =
            new SignatureTransferDetails[](permittedLength_);

        for (uint256 i; i < permittedLength_; i++) {
            TokenPermissions memory tokenPermission =
                params_.permit.permitted[i];

            if (tokenPermission.token == token0_) {
                transfers[i] = SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount0_
                });
            }
            if (tokenPermission.token == token1_) {
                transfers[i] = SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: amount1_
                });
            }
        }

        permit2.permitTransferFrom(
            params_.permit, transfers, msg.sender, params_.signature
        );
    }

    function _permit2SwapAndAddLengthOne(
        SwapAndAddPermit2Data memory params_,
        address token0_,
        address token1_
    ) internal {
        uint256 permittedLength = params_.permit.permitted.length;
        if (permittedLength != 1) {
            revert LengthMismatch();
        }

        if (params_.permit.permitted[0].token == address(weth)) {
            revert Permit2WethNotAuthorized();
        }

        _permit2SwapAndAdd(permittedLength, params_, token0_, token1_);
    }

    function _permit2SwapAndAddLengthOneOrTwo(
        SwapAndAddPermit2Data memory params_,
        address token0_,
        address token1_
    ) internal {
        uint256 permittedLength = params_.permit.permitted.length;
        if (permittedLength != 2 && permittedLength != 1) {
            revert LengthMismatch();
        }

        _permit2SwapAndAdd(permittedLength, params_, token0_, token1_);
    }

    function _permit2SwapAndAdd(
        uint256 permittedLength_,
        SwapAndAddPermit2Data memory params_,
        address token0_,
        address token1_
    ) internal {
        SignatureTransferDetails[] memory transfers =
            new SignatureTransferDetails[](permittedLength_);

        for (uint256 i; i < permittedLength_; i++) {
            TokenPermissions memory tokenPermission =
                params_.permit.permitted[i];

            if (tokenPermission.token == token0_) {
                transfers[i] = SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: params_
                        .swapAndAddData
                        .addData
                        .amount0Max
                });
            }
            if (tokenPermission.token == token1_) {
                transfers[i] = SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: params_
                        .swapAndAddData
                        .addData
                        .amount1Max
                });
            }
        }

        permit2.permitTransferFrom(
            params_.permit, transfers, msg.sender, params_.signature
        );
    }

    // #endregion internal functions.

    // #region internal view functions.

    function _getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        internal
        view
        returns (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        )
    {
        // TODO check rounding !!!!
        (uint256 amount0, uint256 amount1) =
            IArrakisMetaVault(vault_).totalUnderlying();

        uint256 supply = IERC20(vault_).totalSupply();

        if (amount0 == 0 && amount1 == 0) {
            (amount0, amount1) = IArrakisMetaVault(vault_).getInits();
            supply = 1 ether;
        }

        uint256 proportion0 = amount0 == 0
            ? type(uint256).max
            : FullMath.mulDiv(maxAmount0_, BASE, amount0);
        uint256 proportion1 = amount1 == 0
            ? type(uint256).max
            : FullMath.mulDiv(maxAmount1_, BASE, amount1);

        uint256 proportion =
            proportion0 < proportion1 ? proportion0 : proportion1;

        amount0ToDeposit = FullMath.mulDiv(amount0, proportion, BASE);
        amount1ToDeposit = FullMath.mulDiv(amount1, proportion, BASE);
        shareToMint = FullMath.mulDiv(proportion, supply, BASE);
    }

    // #endregion internal view functions.
}
