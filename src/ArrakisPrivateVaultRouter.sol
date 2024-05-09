// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {
    IArrakisPrivateVaultRouter,
    AddLiquidityData,
    SwapAndAddData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data
} from "./interfaces/IArrakisPrivateVaultRouter.sol";
import {TokenPermissions} from "./structs/SPermit2.sol";
import {IArrakisMetaVaultFactory} from
    "./interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPrivate} from
    "./interfaces/IArrakisMetaVaultPrivate.sol";
import {IPrivateRouterSwapExecutor} from
    "./interfaces/IPrivateRouterSwapExecutor.sol";
import {
    IPermit2,
    SignatureTransferDetails
} from "./interfaces/IPermit2.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {PIPS} from "./constants/CArrakis.sol";

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

contract ArrakisPrivateVaultRouter is
    IArrakisPrivateVaultRouter,
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

    IPrivateRouterSwapExecutor public swapper;

    // #region modifiers.

    modifier onlyPrivateVault(address vault_) {
        if (!factory.isPrivateVault(vault_)) {
            revert OnlyPrivateVault();
        }
        _;
    }

    modifier onlyDepositor(address vault_) {
        address[] memory depositors =
            IArrakisMetaVaultPrivate(vault_).depositors();

        bool isDepositor;
        bool routerIsDepositor;
        uint256 length = depositors.length;
        for (uint256 i; i < length; i++) {
            if (depositors[i] == msg.sender) {
                isDepositor = true;
                continue;
            }

            if (depositors[i] == address(this)) {
                routerIsDepositor = true;
                continue;
            }
        }

        if (!isDepositor) revert OnlyDepositor();
        if (!routerIsDepositor) revert RouterIsNotDepositor();
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
        swapper = IPrivateRouterSwapExecutor(swapper_);
    }

    // #endregion owner functions.

    /// @notice addLiquidity adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    function addLiquidity(AddLiquidityData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.vault)
        onlyDepositor(params_.vault)
    {
        // #region checks.

        if (params_.amount0 == 0 && params_.amount1 == 0) {
            revert EmptyAmounts();
        }

        address token0 = IArrakisMetaVault(params_.vault).token0();
        address token1 = IArrakisMetaVault(params_.vault).token1();

        // #endregion checks.

        // #region interactions.

        if (token0 != nativeToken && params_.amount0 > 0) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), params_.amount0
            );
        }

        if (token1 != nativeToken && params_.amount1 > 0) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), params_.amount1
            );
        }

        _addLiquidity(
            params_.vault,
            params_.amount0,
            params_.amount1,
            token0,
            token1
        );

        if (msg.value > 0) {
            if (token0 == nativeToken && msg.value > params_.amount0)
            {
                payable(msg.sender).sendValue(
                    msg.value - params_.amount0
                );
            } else if (
                token1 == nativeToken && msg.value > params_.amount1
            ) {
                payable(msg.sender).sendValue(
                    msg.value - params_.amount1
                );
            }
        }

        // #endregion interactions.
    }

    /// @notice swapAndAddLiquidity transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.addData.vault)
        onlyDepositor(params_.addData.vault)
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        // #region checks.

        if (
            params_.addData.amount0 == 0
                && params_.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
        }

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        if (
            token0 == nativeToken && params_.addData.amount0 > 0
                && msg.value != params_.addData.amount0
        ) {
            revert NotEnoughNativeTokenSent();
        }

        if (
            token1 == nativeToken && params_.addData.amount1 > 0
                && msg.value != params_.addData.amount1
        ) {
            revert NotEnoughNativeTokenSent();
        }

        // #region interactions.

        if (params_.addData.amount0 > 0 && token0 != nativeToken) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), params_.addData.amount0
            );
        }
        if (params_.addData.amount1 > 0 && token1 != nativeToken) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), params_.addData.amount1
            );
        }

        // #endregion interactions.

        (amount0Diff, amount1Diff) =
        _swapAndAddLiquiditySendBackLeftOver(params_, token0, token1);
    }

    /// @notice addLiquidityPermit2 adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.addData.vault)
        onlyDepositor(params_.addData.vault)
    {
        // #region checks.
        if (
            params_.addData.amount0 == 0
                && params_.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
        }

        address token0 =
            IArrakisMetaVault(params_.addData.vault).token0();
        address token1 =
            IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        _permit2AddLengthOneOrTwo(
            params_,
            token0,
            token1,
            params_.addData.amount0,
            params_.addData.amount1
        );

        _addLiquidity(
            params_.addData.vault,
            params_.addData.amount0,
            params_.addData.amount1,
            token0,
            token1
        );
    }

    /// @notice swapAndAddLiquidityPermit2 transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function swapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.swapAndAddData.addData.vault)
        onlyDepositor(params_.swapAndAddData.addData.vault)
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        if (
            params_.swapAndAddData.addData.amount0 == 0
                && params_.swapAndAddData.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
        }

        address token0 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token0();
        address token1 = IArrakisMetaVault(
            params_.swapAndAddData.addData.vault
        ).token1();

        _permit2SwapAndAddLengthOneOrTwo(params_, token0, token1);

        (amount0Diff, amount1Diff) =
        _swapAndAddLiquiditySendBackLeftOver(
            params_.swapAndAddData, token0, token1
        );
    }

    /// @notice wrapAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    function wrapAndAddLiquidity(AddLiquidityData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.vault)
        onlyDepositor(params_.vault)
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.

        // #region checks.
        if (params_.amount0 == 0 && params_.amount1 == 0) {
            revert EmptyAmounts();
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

        if (token0 != address(weth) && params_.amount0 > 0) {
            IERC20(token0).safeTransferFrom(
                msg.sender, address(this), params_.amount0
            );
        }

        if (token1 != address(weth) && params_.amount1 > 0) {
            IERC20(token1).safeTransferFrom(
                msg.sender, address(this), params_.amount1
            );
        }

        _addLiquidity(
            params_.vault,
            params_.amount0,
            params_.amount1,
            token0,
            token1
        );

        if (token0 == address(weth) && msg.value > params_.amount0) {
            weth.withdraw(msg.value - params_.amount0);
            payable(msg.sender).sendValue(msg.value - params_.amount0);
        } else if (
            token1 == address(weth) && msg.value > params_.amount1
        ) {
            weth.withdraw(msg.value - params_.amount1);
            payable(msg.sender).sendValue(msg.value - params_.amount1);
        }

        // #endregion interactions.
    }

    /// @notice wrapAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidity(SwapAndAddData memory params_)
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.addData.vault)
        onlyDepositor(params_.addData.vault)
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.

        if (
            params_.addData.amount0 == 0
                && params_.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
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
            if (params_.addData.amount0 > 0) {
                IERC20(token0).safeTransferFrom(
                    msg.sender, address(this), params_.addData.amount0
                );
            }
        } else if (params_.addData.amount0 != msg.value) {
            revert MsgValueDTAmount();
        }
        if (token1 != address(weth)) {
            if (params_.addData.amount1 > 0) {
                IERC20(token1).safeTransferFrom(
                    msg.sender, address(this), params_.addData.amount1
                );
            }
        } else if (params_.addData.amount1 != msg.value) {
            revert MsgValueDTAmount();
        }

        // #endregion interactions.
        (amount0Diff, amount1Diff) =
            _swapAndAddLiquidity(params_, token0, token1);
    }

    /// @notice wrapAndAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    function wrapAndAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.addData.vault)
        onlyDepositor(params_.addData.vault)
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.
        if (
            params_.addData.amount0 == 0
                && params_.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
        }

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
            params_,
            token0,
            token1,
            params_.addData.amount0,
            params_.addData.amount1
        );

        _addLiquidity(
            params_.addData.vault,
            params_.addData.amount0,
            params_.addData.amount1,
            token0,
            token1
        );

        if (
            token0 == address(weth)
                && msg.value > params_.addData.amount0
        ) {
            weth.withdraw(msg.value - params_.addData.amount0);
            payable(msg.sender).sendValue(
                msg.value - params_.addData.amount0
            );
        } else if (
            token1 == address(weth)
                && msg.value > params_.addData.amount1
        ) {
            weth.withdraw(msg.value - params_.addData.amount1);
            payable(msg.sender).sendValue(
                msg.value - params_.addData.amount1
            );
        }
    }

    /// @notice wrapAndSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wrapAndSwapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPrivateVault(params_.swapAndAddData.addData.vault)
        onlyDepositor(params_.swapAndAddData.addData.vault)
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        if (msg.value == 0) {
            revert MsgValueZero();
        }

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        if (
            params_.swapAndAddData.addData.amount0 == 0
                && params_.swapAndAddData.addData.amount1 == 0
        ) {
            revert EmptyAmounts();
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
                && params_.swapAndAddData.addData.amount0 != msg.value
        ) {
            revert MsgValueDTAmount();
        }
        if (
            token1 == address(weth)
                && params_.swapAndAddData.addData.amount1 != msg.value
        ) {
            revert MsgValueDTAmount();
        }

        _permit2SwapAndAddLengthOne(params_, token0, token1);

        (amount0Diff, amount1Diff) = _swapAndAddLiquidity(
            params_.swapAndAddData, token0, token1
        );
    }

    receive() external payable {}

    // #region internal functions.

    function _addLiquidity(
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
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

        IArrakisMetaVaultPrivate(vault_).deposit{value: valueToSend}(
            amount0_, amount1_
        );

        // #region assertion check to verify if vault exactly what expected.
        // NOTE: check rebase edge case?
        if (
            (
                token0_ == nativeToken
                    && balance0 - amount0_ != address(this).balance
            )
                || (
                    token0_ != nativeToken
                        && balance0 - amount0_
                            != IERC20(token0_).balanceOf(address(this))
                )
        ) {
            revert Deposit0();
        }
        if (
            (
                token1_ == nativeToken
                    && balance1 - amount1_ != address(this).balance
            )
                || (
                    token1_ != nativeToken
                        && balance1 - amount1_
                            != IERC20(token1_).balanceOf(address(this))
                )
        ) {
            revert Deposit1();
        }
        // #endregion  assertion check to verify if vault exactly what expected.
    }

    function _swapAndAddLiquidity(
        SwapAndAddData memory params_,
        address token0_,
        address token1_
    ) internal returns (uint256 amount0Diff, uint256 amount1Diff) {
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

        uint256 amount0Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount0 - amount0Diff
            : params_.addData.amount0 + amount0Diff;
        uint256 amount1Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount1 + amount1Diff
            : params_.addData.amount1 - amount1Diff;

        _addLiquidity(
            params_.addData.vault,
            amount0Use,
            amount1Use,
            token0_,
            token1_
        );
    }

    function _swapAndAddLiquiditySendBackLeftOver(
        SwapAndAddData memory params_,
        address token0_,
        address token1_
    ) internal returns (uint256 amount0Diff, uint256 amount1Diff) {
        (amount0Diff, amount1Diff) =
            _swapAndAddLiquidity(params_, token0_, token1_);
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
                        .amount0
                });
            }
            if (tokenPermission.token == token1_) {
                transfers[i] = SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: params_
                        .swapAndAddData
                        .addData
                        .amount1
                });
            }
        }

        permit2.permitTransferFrom(
            params_.permit, transfers, msg.sender, params_.signature
        );
    }

    // #endregion internal functions.
}
