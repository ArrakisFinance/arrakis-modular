// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Dex {
    IERC20Metadata public immutable token0;
    IERC20Metadata public immutable token1;

    constructor(address token0_, address token1_) {
        token0 = IERC20Metadata(token0_);
        token1 = IERC20Metadata(token1_);
    }

    function swap(
        bool isZeroForOne,
        uint256 amount0_,
        uint256 amount1_
    ) external {
        if (isZeroForOne) {
            token0.transferFrom(msg.sender, address(this), amount0_);
            token1.transfer(msg.sender, amount1_);
        } else {
            token0.transfer(msg.sender, amount0_);
            token1.transferFrom(msg.sender, address(this), amount1_);
        }
    }
}
