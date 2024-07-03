// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    ArrakisPrivateVaultMock,
    NATIVE_COIN
} from "./ArrakisPrivateVaultMock.sol";

import {console} from "forge-std/console.sol";

contract ArrakisPrivateVaultMockBuggy2 is ArrakisPrivateVaultMock {
    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable override {
        amount1_ = amount1_ - 2;
        if (address(token0) != NATIVE_COIN) {
            token0.transferFrom(msg.sender, address(this), amount0_);
        }

        if (address(token1) != NATIVE_COIN) {
            token1.transferFrom(msg.sender, address(this), amount1_);
        } else {
            payable(msg.sender).transfer(2);
        }
    }
}
