// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IUniV4StandardModule} from "./IUniV4StandardModule.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

interface IUniV4StandardModuleResolver {
    // #region errors.

    error MaxAmountsTooLow();
    error AddressZero();
    error MintZero();
    error NotSupported();
    error AmountsOverMaxAmounts();

    // #endregion errors.

    // #region view/pure functions.

    function poolManager() external returns (address);

    function computeBurnAmounts(
        IUniV4StandardModule.Range calldata range_,
        PoolId poolId_,
        address module_,
        uint160 sqrtPriceX96_,
        uint256 proportion_
    ) external view returns (uint256 amount0, uint256 amount1);

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) external pure returns (uint256 mintAmount);

    // #endregion view/pure functions.
}
