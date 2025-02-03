// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IMigrationHelper} from "../interfaces/IMigrationHelper.sol";
import {ISafe, Operation} from "../interfaces/ISafe.sol";
import {IPalmTerms} from "../interfaces/IPalmTerms.sol";
import {
    IArrakisStandardManager,
    SetupParams
} from "../interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVaultFactory} from
    "../interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisV2} from "../interfaces/IArrakisV2.sol";
import {IArrakisMetaVaultPrivate} from
    "../interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

/// @title migration contract that will help migrate from V2 palm vault
/// to modular private vault.
/// #@dev this contract intend to be used as a safe module.
contract MigrationHelper is IMigrationHelper, Ownable {
    // #region immutable.

    address public immutable palmTerms;
    address public immutable factory;
    address public immutable manager;

    // #endregion immutable.

    constructor(
        address palmTerms_,
        address factory_,
        address manager_,
        address owner_
    ) {
        if (
            palmTerms_ == address(0) || factory_ == address(0)
                || manager_ == address(0)
        ) {
            revert AddressZero();
        }
        palmTerms = palmTerms_;
        factory = factory_;
        manager = manager_;

        _initializeOwner(owner_);
    }

    function migrateVault(
        Migration calldata params_
    ) external onlyOwner returns (address vault) {
        // #region close term.

        bytes memory payload;
        bool success;

        address token0 = address(params_.closeTerm.vault.token0());
        address token1 = address(params_.closeTerm.vault.token1());

        {
            payload = abi.encodeWithSelector(
                IPalmTerms.closeTerm.selector,
                params_.closeTerm.vault,
                params_.safe,
                params_.closeTerm.newOwner_,
                params_.closeTerm.newManager_
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                palmTerms, 0, payload, Operation.Call
            );

            if (!success) {
                revert CloseTermsErr();
            }
        }

        // #endregion close term.

        // #region create modular vault.

        {
            bytes memory initManagementPayload = abi.encode(
                params_.vaultCreation.oracle,
                params_.vaultCreation.maxDeviation,
                params_.vaultCreation.cooldownPeriod,
                params_.safe,
                params_.vaultCreation.stratAnnouncer,
                params_.vaultCreation.maxSlippage
            );

            payload = abi.encodeWithSelector(
                IArrakisMetaVaultFactory.deployPrivateVault.selector,
                params_.vaultCreation.salt,
                token0,
                token1,
                params_.safe,
                params_.vaultCreation.upgradeableBeacon,
                params_.vaultCreation.moduleCreationPayload,
                initManagementPayload
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                factory, 0, payload, Operation.Call
            );

            if (!success) {
                revert VaultCreationErr();
            }
        }

        // #endregion create modular vault.

        // #region whitelist safe as depositor.

        {
            address[] memory depositors = new address[](1);
            depositors[0] = params_.safe;

            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.whitelistDepositors.selector,
                depositors
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                params_.vault, 0, payload, Operation.Call
            );

            if (!success) {
                revert WhitelistDepositorErr();
            }
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            address module =
                address(IArrakisMetaVault(params_.vault).module());

            if (params_.deposit.amount0 > 0) {
                payload = abi.encodeWithSelector(
                    IERC20.approve.selector,
                    module,
                    params_.deposit.amount0
                );

                success = ISafe(params_.safe)
                    .execTransactionFromModule(
                    token0, 0, payload, Operation.Call
                );

                if (!success) {
                    revert Approval0Err();
                }
            }

            if (params_.deposit.amount1 > 0) {
                payload = abi.encodeWithSelector(
                    IERC20.approve.selector,
                    module,
                    params_.deposit.amount1
                );

                success = ISafe(params_.safe)
                    .execTransactionFromModule(
                    token1, 0, payload, Operation.Call
                );

                if (!success) {
                    revert Approval1Err();
                }
            }

            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.deposit.selector,
                params_.deposit.amount0,
                params_.deposit.amount1
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                params_.vault, 0, payload, Operation.Call
            );

            if (!success) {
                revert DepositErr();
            }
        }

        // #endregion deposit into the vault.

        // #region rebalance as executor.

        {
            payload = abi.encodeWithSelector(
                IArrakisStandardManager.rebalance.selector,
                params_.vault,
                params_.rebalancePayloads
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                manager, 0, payload, Operation.Call
            );

            if (!success) {
                revert RebalanceErr();
            }
        }

        // #endregion rebalance as executor.

        // #region change executor.

        {
            (
                ,
                uint256 cooldownPeriod,
                IOracleWrapper oracle,
                uint24 maxDeviation,
                ,
                address stratAnnouncer,
                uint24 maxSlippagePIPS,
            ) = IArrakisStandardManager(manager).vaultInfo(
                params_.vault
            );

            SetupParams memory setupParams = SetupParams({
                vault: params_.vault,
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: params_.executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            payload = abi.encodeWithSelector(
                IArrakisStandardManager.updateVaultInfo.selector,
                setupParams
            );

            success = ISafe(params_.safe).execTransactionFromModule(
                manager, 0, payload, Operation.Call
            );

            if (!success) {
                revert ChangeExecutorErr();
            }
        }

        // #endregion change executor.
    }
}
