// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IMasterChefV3} from "../../../../src/interfaces/IMasterChefV3.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract MasterChefV3Mock is IMasterChefV3, IERC721Receiver {
    mapping(uint256 => uint256) private _cakeRewards;
    mapping(uint256 => address) private _tokenOwners;
    mapping(uint256 => uint128) private _stakedLiquidity;

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function harvest(uint256 tokenId, address to) external override returns (uint256 reward) {
        reward = _cakeRewards[tokenId];
        _cakeRewards[tokenId] = 0;
        // In a real implementation, CAKE would be transferred to 'to'
    }

    function withdraw(uint256 tokenId, address to) external override returns (uint256 reward) {
        reward = _cakeRewards[tokenId];
        _cakeRewards[tokenId] = 0;
        _tokenOwners[tokenId] = address(0);
        _stakedLiquidity[tokenId] = 0;
        // In a real implementation, the NFT would be transferred back to 'to'
    }

    function pendingCake(uint256 tokenId) external view override returns (uint256 reward) {
        return _cakeRewards[tokenId];
    }

    // Mock functions for testing
    function setCakeReward(uint256 tokenId, uint256 reward) external {
        _cakeRewards[tokenId] = reward;
    }

    function setTokenOwner(uint256 tokenId, address owner) external {
        _tokenOwners[tokenId] = owner;
    }

    function setStakedLiquidity(uint256 tokenId, uint128 liquidity) external {
        _stakedLiquidity[tokenId] = liquidity;
    }

    function getTokenOwner(uint256 tokenId) external view returns (address) {
        return _tokenOwners[tokenId];
    }

    function getStakedLiquidity(uint256 tokenId) external view returns (uint128) {
        return _stakedLiquidity[tokenId];
    }
}