// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {INonfungiblePositionManager} from "./INonfungiblePositionManager.sol";
import {IVoter} from "./IVoter.sol";

interface ICLGauge {
    event NotifyReward(address indexed from, uint256 amount);
    event Deposit(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event Withdraw(address indexed user, uint256 indexed tokenId, uint128 indexed liquidityToStake);
    event ClaimFees(address indexed from, uint256 claimed0, uint256 claimed1);
    event ClaimRewards(address indexed from, uint256 amount);

    function nft() external view returns (INonfungiblePositionManager);

    function voter() external view returns (IVoter);

    function feesVotingReward() external view returns (address);

    function periodFinish() external view returns (uint256);

    function rewardRate() external view returns (uint256);

    function rewards(uint256 tokenId) external view returns (uint256);

    function lastUpdateTime(uint256 tokenId) external view returns (uint256);

    function rewardRateByEpoch(uint256) external view returns (uint256);

    function fees0() external view returns (uint256);

    function fees1() external view returns (uint256);

    function WETH9() external view returns (address);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function tickSpacing() external view returns (int24);

    function left() external view returns (uint256 _left);

    function rewardToken() external view returns (address);

    function isPool() external view returns (bool);

    function supportsPayable() external view returns (bool);

    function rewardGrowthInside(uint256 tokenId) external view returns (uint256);

    function initialize(
        address _pool,
        address _feesVotingReward,
        address _rewardToken,
        address _voter,
        address _nft,
        address _token0,
        address _token1,
        int24 _tickSpacing,
        bool _isPool
    ) external;

    function earned(address account, uint256 tokenId) external view returns (uint256);

    function getReward(address account) external;

    function getReward(uint256 tokenId) external;
    function notifyRewardAmount(uint256 amount) external;

    function notifyRewardWithoutClaim(uint256 amount) external;

    function deposit(uint256 tokenId) external;

    function withdraw(uint256 tokenId) external;

    function stakedValues(address depositor) external view returns (uint256[] memory);

    function stakedByIndex(address depositor, uint256 index) external view returns (uint256);

    function stakedContains(address depositor, uint256 tokenId) external view returns (bool);

    function stakedLength(address depositor) external view returns (uint256);
}