// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisV2} from "./IArrakisV2.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

import {
    PoolKey
} from "@uniswap/v4-core/src/types/PoolKey.sol";

interface IMigrationHelper {
    //  #region structs.

    struct InternalStruct {
        bytes payload;
        bool success;
        address token0;
        address token1;
        uint256 amount0;
        uint256 amount1;
        uint256 value;
        bool isInversed;
    }

    struct CloseTerm {
        IArrakisV2 vault;
        // address to, safe will receive the fund.
        address newOwner;
        address newManager;
    }

    struct PoolCreation {
        PoolKey poolKey;
        uint160 sqrtPriceX96;
        bool createPool;
    }

    struct VaultCreation {
        bytes32 salt;
        address upgradeableBeacon;
        uint256 init0;
        uint256 init1;
        IOracleWrapper oracle;
        uint24 maxDeviation;
        uint256 cooldownPeriod;
        address stratAnnouncer;
        uint24 maxSlippage;
    }

    struct Migration {
        address safe;
        CloseTerm closeTerm;
        PoolCreation poolCreation;
        VaultCreation vaultCreation;
        bytes[] rebalancePayloads;
        address executor;
    }

    // #endregion structs.

    // #region errors.

    error AddressZero();
    error CloseTermsErr();
    error WhitelistDepositorErr();
    error Approval0Err();
    error Approval1Err();
    error DepositErr();
    error RebalanceErr();
    error ChangeExecutorErr();
    error WithdrawETH();
    error UnableModuleErr();

    // #endregion errors.

    // #region functions.

    function migrateVault(
        Migration calldata params_
    ) external returns (address vault);

    // #endregion functions.
}
