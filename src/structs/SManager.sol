// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

struct VaultInfo {
    uint256 balance; // prepaid credit for rebalance, is 0 for public vault.
    uint256 lastRebalance; // timestamp of the last rebalance
    bytes datas; // custom bytes that can used to store data needed for rebalance. Is empty for public vault.
    IOracleWrapper oracle;
    uint24 maxSlippage;
    uint256 coolDownPeriod;
    bytes32 strat; // strat type
}

struct SetupParams {
    address vault;
    uint256 balance;
    bytes datas;
    IOracleWrapper oracle;
    uint24 maxSlippage;
    uint256 coolDownPeriod;
    bytes32 strat; // strat type
}
