// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../utils/TestWrapper.sol";

contract ModulePublicRegistryTest is TestWrapper {
    // #region constants properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constants properties.

    address public owner;
    address public guardian;
    address public admin;

    function setUp() public {

    }
}