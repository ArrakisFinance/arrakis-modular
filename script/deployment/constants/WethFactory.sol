// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

library WethFactory {
    function getWeth() internal returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        }
        // polygon
        else if (chainId == 137) {
            return 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
        }
        // optimism
        else if (chainId == 10) {
            return 0x4200000000000000000000000000000000000006;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9;
        }
        // base
        else if (chainId == 8453) {
            return 0x4200000000000000000000000000000000000006;
        }
        // base goerli
        else if (chainId == 84_531) {
            return 0x4200000000000000000000000000000000000006;
        }
        // binance
        else if (chainId == 56) {
            return 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        }
        // gnosis
        else if (chainId == 100) {
            return 0xe91D153E0b41518A2Ce8Dd3D7944Fa863463a97d;
        }
        // Ink
        else if (chainId == 57073) {
            return 0x4200000000000000000000000000000000000006;
        }
        // Unichain
        else if (chainId == 130) {
            return 0x4200000000000000000000000000000000000006;
        }
    }
}
