// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisMetaVault} from "./IArrakisMetaVault.sol";

interface IRouterSwapResolver {
    // #region errors.

    error AddressZero();

    // #endregion errors.

    function calculateSwapAmount(
        IArrakisMetaVault vault,
        uint256 amount0In,
        uint256 amount1In,
        uint256 price18Decimals
    ) external view returns (bool zeroForOne, uint256 swapAmount);
}
