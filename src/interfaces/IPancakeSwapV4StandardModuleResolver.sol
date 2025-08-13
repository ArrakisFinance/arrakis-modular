// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPancakeSwapV4StandardModule} from "./IPancakeSwapV4StandardModule.sol";
import {PoolId} from "@pancakeswap/v4-core/src/types/PoolId.sol";

interface IPancakeSwapV4StandardModuleResolver {
    // #region errors.

    error MaxAmountsTooLow();
    error AddressZero();
    error MintZero();
    error NotSupported();
    error AmountsOverMaxAmounts();
    error SharesZero();
    
    // #endregion errors.

    // #region view/pure functions.

    function poolManager() external returns (address);

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) external pure returns (uint256 mintAmount);

    function computeBurnAmounts(
        IPancakeSwapV4StandardModule.Range memory range_,
        PoolId poolId_,
        address module_,
        uint160 sqrtPriceX96_,
        int24 tick_,
        uint256 proportion_
    ) external view returns (uint256 amount0, uint256 amount1);

    // #endregion view/pure functions.
}