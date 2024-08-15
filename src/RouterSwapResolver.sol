// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IRouterSwapResolver} from
    "./interfaces/IRouterSwapResolver.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisPublicVaultRouter} from
    "./interfaces/IArrakisPublicVaultRouter.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract RouterSwapResolver is IRouterSwapResolver {
    IArrakisPublicVaultRouter public immutable router;

    constructor(address router_) {
        if (router_ == address(0)) {
            revert AddressZero();
        }

        router = IArrakisPublicVaultRouter(router_);
    }

    function calculateSwapAmount(
        IArrakisMetaVault vault_,
        uint256 amount0In_,
        uint256 amount1In_,
        uint256 price18Decimals_
    ) external view returns (bool zeroForOne, uint256 swapAmount) {
        (uint256 gross0, uint256 gross1) =
            _getUnderlyingOrLiquidity(vault_);
        if (gross1 == 0) {
            return (false, amount1In_);
        }
        if (gross0 == 0) {
            return (true, amount0In_);
        }

        uint256 amount0Left;
        uint256 amount1Left;
        if (amount0In_ > 0 && amount1In_ > 0) {
            (, uint256 amount0, uint256 amount1) = router
                .getMintAmounts(address(vault_), amount0In_, amount1In_);
            amount0Left = amount0In_ - amount0;
            amount1Left = amount1In_ - amount1;
        } else {
            amount0Left = amount0In_;
            amount1Left = amount1In_;
        }

        uint256 factor0 =
            10 ** (18 - IERC20Metadata(vault_.token0()).decimals());
        uint256 factor1 =
            10 ** (18 - IERC20Metadata(vault_.token1()).decimals());
        uint256 weightX18 = FullMath.mulDiv(
            gross0 * factor0, 1 ether, gross1 * factor1
        );

        uint256 proportionX18 =
            FullMath.mulDiv(weightX18, price18Decimals_, 1 ether);
        uint256 factorX18 = FullMath.mulDiv(
            proportionX18, 1 ether, proportionX18 + 1 ether
        );

        uint256 value0To1Left =
            (amount0Left * factor0 * price18Decimals_) / 1 ether;
        uint256 value1To0Left = amount1Left * factor1;

        if (value0To1Left > value1To0Left) {
            zeroForOne = true;
            swapAmount = FullMath.mulDiv(
                amount0Left, 1 ether - factorX18, 1 ether
            );
        } else if (value0To1Left < value1To0Left) {
            swapAmount =
                FullMath.mulDiv(amount1Left, factorX18, 1 ether);
        }
    }

    function _getUnderlyingOrLiquidity(IArrakisMetaVault vault_)
        internal
        view
        returns (uint256 gross0, uint256 gross1)
    {
        (gross0, gross1) = vault_.totalUnderlying();
        if (gross0 == 0 && gross1 == 0) {
            (gross0, gross1) = vault_.getInits();
        }
    }
}
