// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {
    IUniswapV3Pool
} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {Range} from "../structs/SUniswap.sol";

library Position {
    function getLiquidityByRange(
        IUniswapV3Pool pool_,
        address self_,
        int24 lowerTick_,
        int24 upperTick_
    ) public view returns (uint128 liquidity) {
        (liquidity, , , , ) = pool_.positions(
            getPositionId(self_, lowerTick_, upperTick_)
        );
    }

    function getPositionId(
        address self_,
        int24 lowerTick_,
        int24 upperTick_
    ) public pure returns (bytes32 positionId) {
        return keccak256(abi.encodePacked(self_, lowerTick_, upperTick_));
    }

    function rangeExists(Range[] memory currentRanges_, Range memory range_)
        public
        pure
        returns (bool ok, uint256 index)
    {
        uint256 len = currentRanges_.length;
        for (uint256 i; i < len; i++) {
            ok =
                range_.lowerTick == currentRanges_[i].lowerTick &&
                range_.upperTick == currentRanges_[i].upperTick &&
                range_.feeTier == currentRanges_[i].feeTier;
            if (ok) {
                index = i;
                break;
            }
        }
    }
}
