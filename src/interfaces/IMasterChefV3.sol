// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IMasterChefV3 {
    function harvest(
        uint256 _tokenId,
        address _to
    ) external returns (uint256 reward);
    function withdraw(
        uint256 _tokenId,
        address _to
    ) external returns (uint256 reward);

    function pendingCake(
        uint256 _tokenId
    ) external view returns (uint256 reward);

    function userPositionInfos(
        uint256 _tokenId
    ) external view returns (
        uint128 liquidity,
        uint128 boostLiquidity,
        int24 tickLower,
        int24 tickUpper,
        uint256 rewardGrowthInside,
        uint256 reward,
        address user,
        uint256 pid,
        uint256 boostMultiplier
    );
}
