// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IDoppler {
    function migrate()
        external
        returns (uint256 amount0, uint256 amount1);
    function positions(
        bytes32 salt_
    )
        external
        view
        returns (
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint8 salt
        );
}
