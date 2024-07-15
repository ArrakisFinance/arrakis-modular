// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {UniV4UpdatePrice} from "./UniV4UpdatePrice.sol";
import {IUniV4BlockBuilder} from
    "../interfaces/IUniV4BlockBuilder.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";
import {UnderlyingPayload} from "../structs/SUniswapV4.sol";

import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {Range as PoolRange} from "../structs/SUniswapV4.sol";

contract UniV4BlockBuilder is UniV4UpdatePrice, IUniV4BlockBuilder {
    constructor(
        address poolManager_,
        address metaVault_,
        address token0_,
        address token1_,
        uint256 init0_,
        uint256 init1_,
        address guardian_,
        bool isInversed_
    )
        UniV4UpdatePrice(
            poolManager_,
            metaVault_,
            token0_,
            token1_,
            init0_,
            init1_,
            guardian_,
            isInversed_
        )
    {}

    /// @dev view function to get amounts of token0/token1 inside ranges as liquidity.
    function getAmountsAndFees()
        external
        view
        returns (
            uint256 amount0,
            uint256 amount1,
            uint256 fees0,
            uint256 fees1
        )
    {
        PoolRange[] memory poolRanges = _getPoolRanges(_ranges.length);

        (address _token0, address _token1) = _getTokens();

        (amount0, amount1, fees0, fees1) = UnderlyingV4
            .totalAmountsAndFees(
            UnderlyingPayload({
                ranges: poolRanges,
                poolManager: poolManager,
                token0: _token0,
                token1: _token1,
                self: address(this)
            })
        );
    }
}
