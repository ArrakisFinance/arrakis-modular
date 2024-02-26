// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ISOT {
    function depositLiquidity(
        uint256 _amount0,
        uint256 _amount1,
        uint160 _expectedSqrtSpotPriceUpperX96,
        uint160 _expectedSqrtSpotPriceLowerX96
    ) external;

    function withdrawLiquidity(
        uint256 _amount0,
        uint256 _amount1,
        address _receiver,
        uint160 _expectedSqrtSpotPriceUpperX96,
        uint160 _expectedSqrtSpotPriceLowerX96
    ) external;

    function setPriceBounds(
        uint128 _sqrtPriceLowX96,
        uint128 _sqrtPriceHighX96,
        uint160 _expectedSqrtSpotPriceUpperX96,
        uint160 _expectedSqrtSpotPriceLowerX96
    ) external;

    function getReservesAtPrice(uint160 sqrtPriceX96_)
        external
        view
        returns (uint128 reserves0, uint128 reserves1);

    function getAmmState()
        external
        view
        returns (
            uint160 sqrtSpotPriceX96,
            uint160 sqrtPriceLowX96,
            uint160 sqrtPriceHighX96
        );
}
