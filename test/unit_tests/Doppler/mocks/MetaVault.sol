// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract MetaVault {
    address public token0;
    address public token1;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }
}