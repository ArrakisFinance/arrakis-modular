// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

struct VaultInfo {
    uint256 lastRebalance; // timestamp of the last rebalance
    uint256 cooldownPeriod;
    IOracleWrapper oracle;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
    uint24 managerFeePIPS;
}

struct SetupParams {
    uint256 cooldownPeriod;
    address vault;
    IOracleWrapper oracle;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
}

struct FeeIncrease {
    uint256 submitTimestamp;
    uint24 newFeePIPS;
}
