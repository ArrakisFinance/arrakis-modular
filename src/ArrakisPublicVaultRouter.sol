// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisPublicVaultRouter, AddLiquidityData, SwapAndAddData, RemoveLiquidityData, AddLiquidityPermit2Data, SwapAndAddPermit2Data, RemoveLiquidityPermit2Data} from "./interfaces/IArrakisPublicVaultRouter.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaToken} from "./interfaces/IArrakisMetaToken.sol";
import {IPermit2} from "./interfaces/IPermit2.sol";
import {ERC20TYPE, PIPS} from "./constants/CArrakis.sol";
import {SignatureTransferDetails} from "./structs/SPermit2.sol";

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

contract ArrakisPublicVaultRouter is
    IArrakisPublicVaultRouter,
    ReentrancyGuard,
    Pausable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using Address for address payable;
    using SafeERC20 for IERC20;

    // #region immutable properties.

    address public immutable nativeToken;
    IPermit2 public immutable permit2;

    // #endregion immutable properties.

    // #region modifiers.

    modifier onlyERC20Type(address vault_) {
        bytes32 vaultType = IArrakisMetaVault(vault_).vaultType();
        if (vaultType != ERC20TYPE) revert OnlyERC20TypeVault(vaultType);
        _;
    }

    // #endregion modifiers.

    constructor(address nativeToken_, address permit2_) {
        nativeToken = nativeToken_;
        permit2 = IPermit2(permit2_);
    }

    function addLiquidity(
        AddLiquidityData memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.vault)
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived)
    {
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

        if (token0 != nativeToken && token1 != nativeToken && msg.value > 0)
            revert NoNativeTokenAndValueNotZero();

        // #endregion checks.

        // #region interactions.

        if (token0 != nativeToken && amount0 > 0) {
            IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0);
        }

        if (token1 != nativeToken && amount1 > 0) {
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

        if (msg.value > 0) {
            if (token0 == nativeToken && msg.value > amount0) {
                payable(msg.sender).sendValue(msg.value - amount0);
            } else if (token1 == nativeToken && msg.value > amount1) {
                payable(msg.sender).sendValue(msg.value - amount1);
            }
        }

        // #endregion interactions.
    }

    function swapAndAddLiquidity(
        SwapAndAddData memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        // #region checks.

        if (params_.addData.amount0Max == 0 && params_.addData.amount1Max == 0)
            revert EmptyMaxAmounts();

        address token0 = IArrakisMetaVault(params_.addData.vault).token0();
        address token1 = IArrakisMetaVault(params_.addData.vault).token1();

        if (token0 != nativeToken && token1 != nativeToken && msg.value > 0)
            revert NoNativeTokenAndValueNotZero();

        // #endregion checks.

        // #region interactions.

        if (token0 != nativeToken && params_.swapData.zeroForOne) {
            IERC20(token0).safeTransferFrom(
                msg.sender,
                address(this),
                params_.swapData.amountInSwap
            );
        }

        if (token1 != nativeToken && !params_.swapData.zeroForOne) {
            IERC20(token1).safeTransferFrom(
                msg.sender,
                address(this),
                params_.swapData.amountInSwap
            );
        }

        // #endregion interactions.

        (
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(params_, token0, token1);
    }

    function removeLiquidity(
        RemoveLiquidityData memory params_
    )
        external
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.vault)
        returns (uint256 amount0, uint256 amount1)
    {
        if (params_.burnAmount == 0) revert NothingToBurn();

        IERC20(params_.vault).safeTransferFrom(
            msg.sender,
            address(this),
            params_.burnAmount
        );

        (amount0, amount1) = _removeLiquidity(params_);
    }

    function addLiquidityPermit2(
        AddLiquidityPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.addData.vault)
        returns (uint256 amount0, uint256 amount1, uint256 sharesReceived)
    {
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

        if (token0 == nativeToken || token1 == nativeToken)
            revert NoNativeToken();

        // #endregion checks.

        _permit2Add(params_, amount0, amount1);

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

    function swapAndAddLiquidityPermit2(
        SwapAndAddPermit2Data memory params_
    )
        external
        payable
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.swapAndAddData.addData.vault)
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 sharesReceived,
            uint256 amount0Diff,
            uint256 amount1Diff
        )
    {
        if (
            params_.swapAndAddData.addData.amount0Max == 0 &&
            params_.swapAndAddData.addData.amount1Max == 0
        ) revert EmptyMaxAmounts();

        address token0 = IArrakisMetaVault(params_.swapAndAddData.addData.vault)
            .token0();
        address token1 = IArrakisMetaVault(params_.swapAndAddData.addData.vault)
            .token1();

        if (token0 == nativeToken || token1 == nativeToken)
            revert NoNativeToken();

        _permit2SwapAndAdd(params_);

        (
            amount0,
            amount1,
            sharesReceived,
            amount0Diff,
            amount1Diff
        ) = _swapAndAddLiquidity(params_.swapAndAddData, token0, token1);
    }

    function removeLiquidityPermit2(
        RemoveLiquidityPermit2Data memory params_
    )
        external
        nonReentrant
        whenNotPaused
        onlyERC20Type(params_.removeData.vault)
        returns (uint256 amount0, uint256 amount1)
    {
        if (params_.removeData.burnAmount == 0) revert NothingToBurn();

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

        (amount0, amount1) = _removeLiquidity(params_.removeData);
    }

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
        address module = IArrakisMetaVault(vault_).module();
        if (token0_ != nativeToken) {
            IERC20(token0_).safeIncreaseAllowance(module, amount0_);
        }
        if (token1_ != nativeToken) {
            IERC20(token1_).safeIncreaseAllowance(module, amount1_);
        }

        uint256 balance0 = IERC20(token0_).balanceOf(address(this));
        uint256 balance1 = IERC20(token1_).balanceOf(address(this));

        IArrakisMetaToken(vault_).mint(shares_, receiver_);

        // #region assertion check to verify if vault exactly what expected.
        if (balance0 - amount0_ != IERC20(token0_).balanceOf(address(this)))
            revert Deposit0();
        if (balance1 - amount1_ != IERC20(token1_).balanceOf(address(this)))
            revert Deposit1();
        // #endregion  assertion check to verify if vault exactly what expected.
    }

    function _swapAndAddLiquidity(
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
        (amount0Diff, amount1Diff) = _swap(params_);

        uint256 amount0Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount0Max - amount0Diff
            : params_.addData.amount0Max + amount0Diff;
        uint256 amount1Use = (params_.swapData.zeroForOne)
            ? params_.addData.amount1Max + amount1Diff
            : params_.addData.amount1Max - amount1Diff;

        (sharesReceived, amount0, amount1) = _getMintAmounts(
            params_.addData.vault,
            amount0Use,
            amount1Use
        );

        if (sharesReceived == 0) revert NothingToMint();

        if (
            amount0 < params_.addData.amount0Min ||
            amount1 < params_.addData.amount1Min ||
            sharesReceived < params_.addData.amountSharesMin
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

        if (msg.value > 0) {
            if (token0_ == nativeToken && msg.value > amount0) {
                payable(msg.sender).sendValue(msg.value - amount0);
            } else if (token1_ == nativeToken && msg.value > amount1) {
                payable(msg.sender).sendValue(msg.value - amount1);
            }
        }

        if (amount0Use > amount0 && token0_ != nativeToken) {
            IERC20(token0_).safeTransfer(msg.sender, amount0Use - amount0);
        }
        if (amount1Use > amount1 && token1_ != nativeToken) {
            IERC20(token1_).safeTransfer(msg.sender, amount1Use - amount1);
        }
    }

    function _removeLiquidity(
        RemoveLiquidityData memory params_
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IArrakisMetaToken(params_.vault).burn(
            params_.burnAmount,
            params_.receiver
        );

        if (amount0 < params_.amount0Min || amount1 < params_.amount1Min)
            revert ReceivedBelowMinimum();
    }

    function _permit2Add(
        AddLiquidityPermit2Data memory params_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        if (params_.permit.permitted.length != 2) revert LengthMismatch();
        SignatureTransferDetails[]
            memory transfers = new SignatureTransferDetails[](2);
        transfers[0] = SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount0_
        });
        transfers[1] = SignatureTransferDetails({
            to: address(this),
            requestedAmount: amount1_
        });
        permit2.permitTransferFrom(
            params_.permit,
            transfers,
            msg.sender,
            params_.signature
        );
    }

    function _permit2SwapAndAdd(SwapAndAddPermit2Data memory params_) internal {
        if (params_.permit.permitted.length != 2) revert LengthMismatch();
        SignatureTransferDetails[]
            memory transfers = new SignatureTransferDetails[](2);
        transfers[0] = SignatureTransferDetails({
            to: address(this),
            requestedAmount: params_.swapAndAddData.addData.amount0Max
        });
        transfers[1] = SignatureTransferDetails({
            to: address(this),
            requestedAmount: params_.swapAndAddData.addData.amount1Max
        });
        permit2.permitTransferFrom(
            params_.permit,
            transfers,
            msg.sender,
            params_.signature
        );
    }

    function _swap(
        SwapAndAddData memory params_
    ) internal returns (uint256 amount0Diff, uint256 amount1Diff) {
        address token0 = IArrakisMetaVault(params_.addData.vault).token0();
        address token1 = IArrakisMetaVault(params_.addData.vault).token1();
        uint256 balanceBefore;
        uint256 valueToSend;
        if (params_.swapData.zeroForOne) {
            if (token0 != nativeToken) {
                balanceBefore = IERC20(token0).balanceOf(address(this));
                IERC20(token0).safeIncreaseAllowance(
                    params_.swapData.swapRouter,
                    params_.swapData.amountInSwap
                );
            } else {
                balanceBefore = address(this).balance;
                valueToSend = params_.swapData.amountInSwap;
            }
        } else {
            if (token1 != nativeToken) {
                balanceBefore = IERC20(token1).balanceOf(address(this));
                IERC20(token1).safeIncreaseAllowance(
                    params_.swapData.swapRouter,
                    params_.swapData.amountInSwap
                );
            } else {
                balanceBefore = address(this).balance;
                valueToSend = params_.swapData.amountInSwap;
            }
        }
        (bool success, ) = params_.swapData.swapRouter.call{value: valueToSend}(
            params_.swapData.swapPayload
        );
        if (!success) revert SwapCallFailed();

        uint256 balance0;
        uint256 balance1;
        if (token0 == nativeToken) balance0 = address(this).balance;
        else balance0 = IERC20(token0).balanceOf(address(this));
        if (token1 == nativeToken) balance1 = address(this).balance;
        else balance1 = IERC20(token1).balanceOf(address(this));
        if (params_.swapData.zeroForOne) {
            amount0Diff = balanceBefore - balance0;
            amount1Diff = balance1;
            if (amount1Diff < params_.swapData.amountOutSwap)
                revert ReceivedBelowMinimum();
        } else {
            amount0Diff = balance0;
            amount1Diff = balanceBefore - balance1;
            if (amount0Diff < params_.swapData.amountOutSwap)
                revert ReceivedBelowMinimum();
        }
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
        (uint256 amount0, uint256 amount1) = IArrakisMetaVault(vault_)
            .totalUnderlying();

        uint256 supply = IERC20(vault_).totalSupply();

        if (amount0 == 0 && amount1 == 0) {
            (amount0, amount1) = IArrakisMetaVault(vault_).getInits();
        }

        uint256 proportion0 = FullMath.mulDiv(maxAmount0_, PIPS, amount0);
        uint256 proportion1 = FullMath.mulDiv(maxAmount1_, PIPS, amount1);

        uint256 proportion = proportion0 < proportion1
            ? proportion0
            : proportion1;

        amount0ToDeposit = FullMath.mulDiv(amount0, proportion, PIPS);
        amount1ToDeposit = FullMath.mulDiv(amount1, proportion, PIPS);
        shareToMint = FullMath.mulDiv(proportion, supply, PIPS);
    }

    // #endregion internal view functions.
}
