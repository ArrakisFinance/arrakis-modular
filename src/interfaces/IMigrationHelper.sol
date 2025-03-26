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

    /// @notice Struct containing informations about the close term.
    struct CloseTerm {
        IArrakisV2 vault;
        // address to, safe will receive the fund.
        address newOwner;
        address newManager;
    }

    /// @notice Struct containing informations about the v4 Pool
    /// that should be used on the new vault. If createPool is true,
    /// the pool will be created.
    struct PoolCreation {
        PoolKey poolKey;
        uint160 sqrtPriceX96;
    }

    /// @notice Struct containing informations about the new
    /// ArrakisMetaVaultPrivate vault to be created.
    struct VaultCreation {
        bytes32 salt;
        address upgradeableBeacon;
        uint256 init0;
        uint256 init1;
        IOracleWrapper oracle;
        bool isUniV4OracleNeedInitilization;
        uint24 maxDeviation;
        uint256 cooldownPeriod;
        address stratAnnouncer;
        uint24 maxSlippage;
    }

    /// @notice Struct containing informations about the migration.
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
    /// @notice Error emitted when the address is zero.
    error AddressZero();
    /// @notice Error emitted when closing arrakisV2 vault fails.
    error CloseTermsErr();
    /// @notice Error emitted when whitelisting safe as depositor fails.
    error WhitelistDepositorErr();
    /// @notice Error emitted when approving module to use token0 fails.
    error Approval0Err();
    /// @notice Error emitted when approving module to use token1 fails.
    error Approval1Err();
    /// @notice Error emitted when depositing through the safe fails.
    error DepositErr();
    /// @notice Error emitted when rebalancing the new ArrakisMetaVaultPrivate fails.
    error RebalanceErr();
    /// @notice Error emitted when updating the executor fails.
    error ChangeExecutorErr();
    /// @notice Error emitted when withdrawing ETH from WETH sm fails.
    error WithdrawETH();
    /// @notice Error emitted when pool creation fails due to initial sqrtPrice not provided by payload.
    error InvalidSqrtPrice();
    /// @notice Error emitted when vault creation fails.
    error VaultCreationErr();
    /// @notice Error emitted when disable module fails.
    error UnableModuleErr();
    // #endregion errors.

    // #region functions.

    /// @notice Migrate a vault from ArrakisV2 to ArrakisMetaVaultPrivate.
    /// @dev can be called by the owner of this migration helper or by the safe.
    /// @param params_ Migration struct, containing informations about how to migrate from
    /// ArrakisV2 vault to a modular vault.
    /// @return vault address of the new ArrakisMetaVaultPrivate vault.
    function migrateVault(
        Migration calldata params_
    ) external returns (address vault);

    // #endregion functions.

    // #region view functions.

    /// @notice Get the address of the arrakisV2 PALMTerms contract.
    function palmTerms() external view returns (address);
    /// @notice Get the address of the arrakis modular meta vault factory.
    function factory() external view returns (address);
    /// @notice Get the address of the arrakis standard manager.
    function manager() external view returns (address);
    /// @notice Get the address of the uni v4 pool manager.
    function poolManager() external view returns (address);
    /// @notice Get the address of the WETH.
    function weth() external view returns (address);

    // #endregion view functions.
}
