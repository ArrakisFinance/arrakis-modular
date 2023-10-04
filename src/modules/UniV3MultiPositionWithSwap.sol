// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {UniV3MultiPosition, IUniswapV3Factory, IArrakisMetaVault, IERC20, FullMath, SafeCast} from "./UniV3MultiPosition.sol";
import {ISwap, IOracleWrapper} from "../interfaces/ISwap.sol";
import {IERC20Decimals} from "../interfaces/IERC20Decimals.sol";

error SwapCallFailed(address target, bytes data);
error PortFolioValueDecreased(
    uint256 before0,
    uint256 before1,
    uint256 after0,
    uint256 after1
);

contract UniV3MultiPositionWithSwap is ISwap, UniV3MultiPosition {
    IOracleWrapper public oracle;

    constructor(IUniswapV3Factory factory_) UniV3MultiPosition(factory_) {}

    function initialize(
        IOracleWrapper oracle_,
        IArrakisMetaVault metaVault_,
        IERC20 token0_,
        IERC20 token1_,
        uint256 init0_,
        uint256 init1_
    ) external initializer {
        oracle = oracle_;

        __ReentrancyGuard_init();
        metaVault = metaVault_;
        token0 = token0_;
        token1 = token1_;
        _init0 = init0_;
        _init1 = init1_;
    }

    function swap(address target_, bytes calldata data_) external {
        (uint256 before0, uint256 before1) = _portfolioValues();

        (bool success, ) = target_.call(data_);
        if (!success) revert SwapCallFailed(target_, data_);

        (uint256 after0, uint256 after1) = _portfolioValues();

        if (after0 < before0 || after1 < before1)
            revert PortFolioValueDecreased(before0, before1, after0, after1);

        emit LogSwap(
            target_,
            data_,
            SafeCast.toInt256(before0) - SafeCast.toInt256(after0),
            SafeCast.toInt256(before1) - SafeCast.toInt256(after1)
        );
    }

    // #region internal functions.

    function _portfolioValues()
        internal
        view
        returns (uint256 value0, uint256 value1)
    {
        (uint256 amount0, uint256 amount1) = totalUnderlying();

        uint8 token0Decimals = IERC20Decimals(address(token0)).decimals();
        uint8 token1Decimals = IERC20Decimals(address(token1)).decimals();

        value0 =
            amount0 +
            FullMath.mulDiv(amount1, oracle.getPrice1(), 10 ** token0Decimals);
        value1 =
            amount1 +
            FullMath.mulDiv(amount0, oracle.getPrice0(), 10 ** token1Decimals);
    }

    // #endregion internal functions.
}
