// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract MetaVaultMock {
    IERC20Metadata public token0;
    IERC20Metadata public token1;

    function setTokens(address token0_, address token1_) external {
        token0 = IERC20Metadata(token0_);
        token1 = IERC20Metadata(token1_);
    }
}