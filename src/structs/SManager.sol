// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

struct VaultInfo {
    uint256 lastRebalance;
    uint256 cooldownPeriod;
    IOracleWrapper oracle;
    uint24 maxDeviation;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
    uint24 managerFeePIPS;
}

struct SetupParams {
    address vault;
    IOracleWrapper oracle;
    uint24 maxDeviation;
    uint256 cooldownPeriod;
    address executor;
    address stratAnnouncer;
    uint24 maxSlippagePIPS;
}

struct FeeIncrease {
    uint256 submitTimestamp;
    uint24 newFeePIPS;
}
