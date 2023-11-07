// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UniV3MultiPosition, IUniswapV3Factory, IArrakisMetaVault, IERC20} from "./UniV3MultiPosition.sol";

contract UniV3MultiPositionNoSwap is UniV3MultiPosition {

    constructor(IUniswapV3Factory factory_) UniV3MultiPosition(factory_) {}

    function initialize(
        IArrakisMetaVault metaVault_,
        IERC20 token0_,
        IERC20 token1_,
        uint256 init0_,
        uint256 init1_
    ) public initializer virtual {
        __ReentrancyGuard_init();
        metaVault = metaVault_;
        token0 = token0_;
        token1 = token1_;
        _init0 = init0_;
        _init1 = init1_;
    }
}
