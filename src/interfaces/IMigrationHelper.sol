// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisV2} from "./IArrakisV2.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

interface IMigrationHelper {
    //  #region structs.

    struct CloseTerm {
        IArrakisV2 vault;
        // address to, safe will receive the fund.
        address newOwner_;
        address newManager_;
    }

    struct VaultCreation {
        bytes32 salt;
        address upgradeableBeacon;
        bytes moduleCreationPayload;
        IOracleWrapper oracle;
        uint24 maxDeviation;
        uint256 cooldownPeriod;
        address stratAnnouncer;
        uint24 maxSlippage;
    }

    struct Deposit {
        uint256 amount0;
        uint256 amount1;
    }

    struct Migration {
        address safe;
        CloseTerm closeTerm;
        VaultCreation vaultCreation;
        address vault;
        Deposit deposit;
        bytes[] rebalancePayloads;
        address executor;
    }

    // #endregion structs.

    // #region errors.

    error AddressZero();
    error CloseTermsErr();
    error VaultCreationErr();
    error WhitelistDepositorErr();
    error Approval0Err();
    error Approval1Err();
    error DepositErr();
    error RebalanceErr();
    error ChangeExecutorErr();

    // #endregion errors.

    // #region functions.

    function migrateVault(
        Migration calldata params_
    ) external returns (address vault);

    // #endregion functions.
}
