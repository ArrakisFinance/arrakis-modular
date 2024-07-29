// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

library ArrakisRoles {
    function getAdmin() internal returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0xb9229ea965FC84f21b63791efC643b2c7ffB77Be;
        }
        // polygon
        else if (chainId == 137) {
            return 0xd06a7cc1a162fDfB515595A2eC1c47B75743C381;
        }
        // optimism
        else if (chainId == 10) {
            return 0x283824e5A6378EaB2695Be7d3cb0919186e37D7C;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x64520Dc190b5015E7d48E87273f6EE69197Cd798;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0x58513D04AB0eD200FC86099bD4847B7A8329d1E8;
        }
        // base
        else if (chainId == 8453) {
            return 0x463a4a038038DE81525f55c456f071241e0a3E66;
        }
        // base goerli
        else if (chainId == 84_531) {
            return 0x0F83FFe2d0779550E74D96B3871216132D527eF5;
        }
        // binance
        else if (chainId == 56) {
            return 0x2CcDA3A99A41342Eb5Ff3c8173828Ac0C5311fba;
        }
        // gnosis
        else if (chainId == 100) {
            return 0x05b1811546e65Dec3Eb703a13aA2885B4f51a32f;
        }
    }

    function getOwner() internal returns (address) {
        uint256 chainId = block.chainid;

        // mainnet
        if (chainId == 1) {
            return 0x5108EF86cF493905BcD35A3736e4B46DeCD7de58;
        }
        // polygon
        else if (chainId == 137) {
            return 0xDEb4C33D5C3E7e32F55a9D6336FE06010E40E3AB;
        }
        // optimism
        else if (chainId == 10) {
            return 0x8636600A864797Aa7ac8807A065C5d8BD9bA3Ccb;
        }
        // arbitrum
        else if (chainId == 42_161) {
            return 0x77BADa8FC2A478f1bc1E1E4980916666187D0dF7;
        }
        // sepolia
        else if (chainId == 11_155_111) {
            return 0x17E41e0B22D781DBBb0bB6978fdabEf84d5d51B1;
        }
        // base
        else if (chainId == 8453) {
            return 0x25CF23B54e25daaE3fe9989a74050b953A343823;
        }
        // base goerli
        else if (chainId == 84_531) {
            return 0x4788290e1fb26c537cBfBb5a8b4E1432795BeEbD;
        }
        // binance
        else if (chainId == 56) {
            return 0x7ddBE55B78FbDe1B0A0b57cc05EE469ccF700585;
        }
        // gnosis
        else if (chainId == 100) {
            return 0x969cA3961FCeaFd3Cb3C1CA9ecdd475babcD704D;
        }
    }
}
