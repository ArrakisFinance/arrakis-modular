// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ArrakisPrivateVaultMock, NATIVE_COIN} from "./ArrakisPrivateVaultMock.sol";

contract ArrakisPrivateVaultMockBuggy is ArrakisPrivateVaultMock {
    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable override {
        amount0_ = amount0_ - 2;
        if (address(token0) == NATIVE_COIN) {
            require(amount0_ == msg.value);
        } else {
            token0.transferFrom(msg.sender, address(this), amount0_);
        }
        if (address(token1) == NATIVE_COIN) {
            require(amount1_ == msg.value);
        } else {
            token1.transferFrom(msg.sender, address(this), amount1_);
        }
    }
}
