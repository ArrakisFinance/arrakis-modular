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
}
