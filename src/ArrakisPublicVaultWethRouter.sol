// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    ArrakisPublicVaultRouter,
    AddLiquidityData,
    SwapAndAddData,
    RemoveLiquidityData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data,
    RemoveLiquidityPermit2Data
} from "./ArrakisPublicVaultRouter.sol";
import {IArrakisPublicVaultWethRouter} from "./interfaces/IArrakisPublicVaultWethRouter.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {SignatureTransferDetails} from "./interfaces/IPermit2.sol";
import {IWETH9} from "./interfaces/Iweth9.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract ArrakisPublicVaultWethRouter is ArrakisPublicVaultRouter, IArrakisPublicVaultWethRouter {

    using Address for address payable;
    using SafeERC20 for IERC20;

    // #region immutable properties.

    IWETH9 public immutable weth;

    // #endregion immutable properties.

    constructor(
        address nativeToken_,
        address permit2_,
        address swapper_,
        address owner_,
        address factory_,
        address weth_
    ) ArrakisPublicVaultRouter(nativeToken_, permit2_, swapper_, owner_, factory_) {
        if(weth_ == address(0))
            revert AddressZero();
        weth = IWETH9(weth_);
    }

    /// @notice wethAndAddLiquidity wrap eth and adds liquidity to meta vault of iPnterest (mints L tokens)
    /// @param params_ AddLiquidityData struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wethAndAddLiquidity(
        AddLiquidityData memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.vault)
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived)
    {
        if(msg.value == 0)
            revert MsgValueZero();

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.

        // #region checks.
        if (params_.amount0Max == 0 && params_.amount1Max == 0)
            revert EmptyMaxAmounts();

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.vault,
            params_.amount0Max,
            params_.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.amount0Min ||
            amount1 < params_.amount1Min ||
            sharesReceived < params_.amountSharesMin
        ) revert BelowMinAmounts();

        address token0 = IArrakisMetaVault(params_.vault).token0();
        address token1 = IArrakisMetaVault(params_.vault).token1();

        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        // #endregion checks.

        // #region interactions.

        if (token0 != address(weth) && amount0 > 0) {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        }

        if (token1 != address(weth) && amount1 > 0) {
            IERC20(token1).safeTransferFrom(msg.sender, address(this), amount1);
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

    /// @notice wethAndSwapAndAddLiquidity wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddData struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wethAndSwapAndAddLiquidity(
        SwapAndAddData memory params_
    )
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
        if(msg.value == 0)
            revert MsgValueZero();

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.

        if (params_.addData.amount0Max == 0 && params_.addData.amount1Max == 0)
            revert EmptyMaxAmounts();

        address token0 = IArrakisMetaVault(params_.addData.vault).token0();
        address token1 = IArrakisMetaVault(params_.addData.vault).token1();

        // #endregion checks.

        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        // #region interactions.

        if(token0 != address(weth)) {
            if (params_.addData.amount0Max > 0)
                    IERC20(token0).safeTransferFrom(
                    msg.sender,
                    address(this),
                    params_.addData.amount0Max
                );
        } else if(params_.addData.amount0Max != msg.value)
            revert MsgValueDTMaxAmount();
        if(token1 != address(weth)) {
            if(params_.addData.amount1Max > 0)
                IERC20(token1).safeTransferFrom(
                    msg.sender,
                    address(this),
                    params_.addData.amount1Max
                );
        } else if(params_.addData.amount1Max != msg.value)
            revert MsgValueDTMaxAmount();

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

        if(amount0Use > amount0) {
            if(token0 == address(weth)) {
                weth.withdraw(amount0Use - amount0);
                payable(msg.sender).sendValue(amount0Use - amount0);
            } else {
                IERC20(token0).safeTransfer(msg.sender, amount0Use - amount0);
            }
        }

        if(amount1Use > amount1) {
            if(token1 == address(weth)) {
                weth.withdraw(amount1Use - amount1);
                payable(msg.sender).sendValue(amount1Use - amount1);
            } else {
                IERC20(token1).safeTransfer(msg.sender, amount1Use - amount1);
            }
        }
    }

    /// @notice removeLiquidityAndUnwrap removes liquidity from vault and burns LP tokens and then wrap weth
    /// to send it to receiver.
    /// @param params_ RemoveLiquidityData struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidityAndUnwrap(
        RemoveLiquidityData memory params_
    ) 
        external
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.vault)
        returns (uint256 amount0, uint256 amount1) 
    {
        if (params_.burnAmount == 0) revert NothingToBurn();

        address token0 = IArrakisMetaVault(params_.vault).token0();
        address token1 = IArrakisMetaVault(params_.vault).token1();

        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        IERC20(params_.vault).safeTransferFrom(
            msg.sender,
            address(this),
            params_.burnAmount
        );

        address receiver = params_.receiver;
        params_.receiver = payable(address(this));

        (amount0, amount1) = _removeLiquidity(params_);


        if(amount0 > 0) {
            if(token0 == address(weth)) {
                weth.withdraw(amount0);
                payable(receiver).sendValue(amount0);
            } else {
                IERC20(token0).safeTransfer(receiver, amount0);
            }
        }
        if(amount1 > 0) {
            if(token1 == address(weth)) {
                weth.withdraw(amount1);
                payable(receiver).sendValue(amount1);
            } else {
                IERC20(token1).safeTransfer(receiver, amount1);
            }
        }
    }

    /// @notice wethAddLiquidityPermit2 wrap eth and adds liquidity to public vault of interest (mints LP tokens)
    /// @param params_ AddLiquidityPermit2Data struct containing data for adding liquidity
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    function wethAddLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.addData.vault)
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived)
    {
        if(msg.value == 0)
            revert MsgValueZero();

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        // #region checks.
        if (params_.addData.amount0Max == 0 && params_.addData.amount1Max == 0)
            revert EmptyMaxAmounts();

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.addData.vault,
            params_.addData.amount0Max,
            params_.addData.amount1Max
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.addData.amount0Min ||
            amount1 < params_.addData.amount1Min ||
            sharesReceived < params_.addData.amountSharesMin
        ) revert BelowMinAmounts();

        address token0 = IArrakisMetaVault(params_.addData.vault).token0();
        address token1 = IArrakisMetaVault(params_.addData.vault).token1();

        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        // #endregion checks.

        _permit2AddLengthOne(params_, token0, token1, amount0, amount1);

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
    
    /// @notice wethSwapAndAddLiquidityPermit2 wrap eth and transfer tokens to and calls RouterSwapExecutor
    /// @param params_ SwapAndAddPermit2Data struct containing data for swap
    /// @return amount0 amount of token0 transferred from msg.sender to mint `mintAmount`
    /// @return amount1 amount of token1 transferred from msg.sender to mint `mintAmount`
    /// @return sharesReceived amount of public vault tokens transferred to `receiver`
    /// @return amount0Diff token0 balance difference post swap
    /// @return amount1Diff token1 balance difference post swap
    function wethSwapAndAddLiquidityPermit2(
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
        if(msg.value == 0)
            revert MsgValueZero();

        // #region wrap eth.

        weth.deposit{value: msg.value}();

        // #endregion wrap eth.
        if (
            params_.swapAndAddData.addData.amount0Max == 0 &&
            params_.swapAndAddData.addData.amount1Max == 0
        ) revert EmptyMaxAmounts();

        address token0 = IArrakisMetaVault(params_.swapAndAddData.addData.vault)
            .token0();
        address token1 = IArrakisMetaVault(params_.swapAndAddData.addData.vault)
            .token1();
        
        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        if(token0 == address(weth) && params_.swapAndAddData.addData.amount0Max != msg.value)
            revert MsgValueDTMaxAmount();
        if(token1 == address(weth) && params_.swapAndAddData.addData.amount1Max != msg.value)
            revert MsgValueDTMaxAmount();

        _permit2SwapAndAddLengthOne(params_, token0, token1);

        (
            ,
            ,
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(params_.swapAndAddData, token0, token1);

        /// @dev hack to get rid of stack too depth
        uint256 amount0Use = (params_.swapAndAddData.swapData.zeroForOne)
            ? params_.swapAndAddData.addData.amount0Max - amount0Diff
            : params_.swapAndAddData.addData.amount0Max + amount0Diff;
        uint256 amount1Use = (params_.swapAndAddData.swapData.zeroForOne)
            ? params_.swapAndAddData.addData.amount1Max + amount1Diff
            : params_.swapAndAddData.addData.amount1Max - amount1Diff;

        if(amount0Use > amount0) {
            if(token0 == address(weth)) {
                weth.withdraw(amount0Use - amount0);
                payable(msg.sender).sendValue(amount0Use - amount0);
            } else {
                IERC20(token0).safeTransfer(msg.sender, amount0Use - amount0);
            }
        }

        if(amount1Use > amount1) {
            if(token1 == address(weth)) {
                weth.withdraw(amount1Use - amount1);
                payable(msg.sender).sendValue(amount1Use - amount1);
            } else {
                IERC20(token1).safeTransfer(msg.sender, amount1Use - amount1);
            }
        }
    }

    /// @notice removeLiquidityPermit2AndUnwrap removes liquidity from vault and burns LP tokens and then wrap weth
    /// to send it to receiver.
    /// @param params_ RemoveLiquidityPermit2Data struct containing data for withdrawals
    /// @return amount0 actual amount of token0 transferred to receiver for burning `burnAmount`
    /// @return amount1 actual amount of token1 transferred to receiver for burning `burnAmount`
    function removeLiquidityPermit2AndUnwrap(
         RemoveLiquidityPermit2Data memory params_
    )
        external
        nonReentrant
        whenNotPaused
        onlyPublicVault(params_.removeData.vault)
        returns (uint256 amount0, uint256 amount1)
    {
        if (params_.removeData.burnAmount == 0) revert NothingToBurn();

        address token0 = IArrakisMetaVault(params_.removeData.vault).token0();
        address token1 = IArrakisMetaVault(params_.removeData.vault).token1();

        if(token0 == nativeToken || token1 == nativeToken)
            revert NativeTokenNotSupported();
        if(token0 != address(weth) && token1 != address(weth))
            revert NoWethToken();

        SignatureTransferDetails
            memory transferDetails = SignatureTransferDetails({
                to: address(this),
                requestedAmount: params_.removeData.burnAmount
            });
        permit2.permitTransferFrom(
            params_.permit,
            transferDetails,
            msg.sender,
            params_.signature
        );

        address receiver = params_.removeData.receiver;
        params_.removeData.receiver = payable(address(this));

        (amount0, amount1) = _removeLiquidity(params_.removeData);

        if(amount0 > 0) {
            if(token0 == address(weth)) {
                weth.withdraw(amount0);
                payable(receiver).sendValue(amount0);
            } else {
                IERC20(token0).safeTransfer(receiver, amount0);
            }
        }
        if(amount1 > 0) {
            if(token1 == address(weth)) {
                weth.withdraw(amount1);
                payable(receiver).sendValue(amount1);
            } else {
                IERC20(token1).safeTransfer(receiver, amount1);
            }
        }
    }

    // #region internal functions.

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

        if(params_.permit.permitted[0].token == address(weth))
            revert Permit2WethNotAuthorized();

        _permit2Add(permittedLength, params_, token0_, token1_, amount0_, amount1_);
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

        if(params_.permit.permitted[0].token == address(weth))
            revert Permit2WethNotAuthorized();

        _permit2SwapAndAdd(permittedLength, params_, token0_, token1_);
    }

    // #endregion internal functions.
}