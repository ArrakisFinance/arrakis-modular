// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IMigrationHelper} from "../interfaces/IMigrationHelper.sol";
import {ISafe, Operation} from "../interfaces/ISafe.sol";
import {IPALMTerms} from "../interfaces/IPALMTerms.sol";
import {
    IArrakisStandardManager,
    SetupParams
} from "../interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVaultFactory} from
    "../interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVaultPrivate} from
    "../interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IUniV4StandardModule} from
    "../interfaces/IUniV4StandardModule.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";
import {IWETH9} from "../interfaces/IWETH9.sol";

// #region v4.

import {CurrencyLibrary} from
    "@uniswap/v4-core/src/types/Currency.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

// #endregion v4.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

/// @title migration contract that will help migrate from V2 palm vault
/// to modular private vault with uniswap v4 module.
/// #@dev this contract intend to be used as a safe module.
contract MigrationHelper is IMigrationHelper, Ownable {
    using StateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // #region immutable.

    /// @inheritdoc IMigrationHelper
    address public immutable palmTerms;
    /// @inheritdoc IMigrationHelper
    address public immutable factory;
    /// @inheritdoc IMigrationHelper
    address public immutable manager;
    /// @inheritdoc IMigrationHelper
    address public immutable poolManager;
    /// @inheritdoc IMigrationHelper
    address public immutable weth;

    // #endregion immutable.

    constructor(
        address palmTerms_,
        address factory_,
        address manager_,
        address poolManager_,
        address weth_,
        address owner_
    ) {
        if (
            palmTerms_ == address(0) || factory_ == address(0)
                || poolManager_ == address(0) || manager_ == address(0)
                || weth_ == address(0) || owner_ == address(0)
        ) {
            revert AddressZero();
        }
        palmTerms = palmTerms_;
        factory = factory_;
        manager = manager_;
        poolManager = poolManager_;
        weth = weth_;

        _initializeOwner(owner_);
    }

    /// @inheritdoc IMigrationHelper
    function migrateVault(
        Migration calldata params_
    ) external returns (address vault) {
        {
            address owner = owner();

            if (msg.sender != owner && msg.sender != params_.safe) {
                revert Unauthorized();
            }
        }

        // #region close term.

        InternalStruct memory state;

        state.token0 = address(params_.closeTerm.vault.token0());
        state.token1 = address(params_.closeTerm.vault.token1());

        state.amount0 = IERC20(state.token0).balanceOf(params_.safe);
        state.amount1 = IERC20(state.token1).balanceOf(params_.safe);

        {
            state.payload = abi.encodeWithSelector(
                IPALMTerms.closeTerm.selector,
                params_.closeTerm.vault,
                params_.safe,
                params_.closeTerm.newOwner,
                params_.closeTerm.newManager
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                palmTerms, 0, state.payload, Operation.Call
            );

            if (!state.success) {
                revert CloseTermsErr();
            }
        }

        state.amount0 = IERC20(state.token0).balanceOf(params_.safe)
            - state.amount0;
        state.amount1 = IERC20(state.token1).balanceOf(params_.safe)
            - state.amount1;

        // #endregion close term.

        // #region create pool on v4 if needed.

        {
            PoolId poolId = params_.poolCreation.poolKey.toId();

            (uint160 price,,,) =
                IPoolManager(poolManager).getSlot0(poolId);

            if (price == 0) {
                if (params_.poolCreation.sqrtPriceX96 == 0) {
                    revert InvalidSqrtPrice();
                }

                IPoolManager(poolManager).initialize(
                    params_.poolCreation.poolKey,
                    params_.poolCreation.sqrtPriceX96
                );
            }
        }

        // #endregion create pool on v4 if needed.

        // #region create module payload.

        {
            if (
                params_.poolCreation.poolKey.currency0
                    == CurrencyLibrary.ADDRESS_ZERO
            ) {
                state.payload = "";
                if (state.token0 == weth) {
                    if (state.amount0 > 0) {
                        state.payload = abi.encodeWithSelector(
                            IWETH9.withdraw.selector, state.amount0
                        );
                    }
                    state.value = state.amount0;
                    if (NATIVE_COIN < state.token1) {
                        state.token0 = NATIVE_COIN;
                    } else {
                        state.token0 = state.token1;
                        (state.amount0, state.amount1) =
                            (state.amount1, state.amount0);
                        state.token1 = NATIVE_COIN;
                        state.isInversed = true;
                    }
                }

                if (state.token1 == weth) {
                    if (state.amount1 > 0) {
                        state.payload = abi.encodeWithSelector(
                            IWETH9.withdraw.selector, state.amount1
                        );
                    }
                    state.value = state.amount1;
                    if (NATIVE_COIN < state.token0) {
                        state.token1 = state.token0;
                        (state.amount1, state.amount0) =
                            (state.amount0, state.amount1);
                        state.token0 = NATIVE_COIN;
                    } else {
                        state.token1 = NATIVE_COIN;
                        state.isInversed = true;
                    }
                }

                if (state.payload.length > 0) {
                    state.success = ISafe(params_.safe)
                        .execTransactionFromModule(
                        weth, 0, state.payload, Operation.Call
                    );

                    if (!state.success) {
                        revert WithdrawETH();
                    }
                }
            }
        }

        // #endregion create module payload.

        // #region create modular vault.

        {
            bytes memory moduleCreationPayload = abi
                .encodeWithSelector(
                IUniV4StandardModule.initialize.selector,
                params_.vaultCreation.init0,
                params_.vaultCreation.init1,
                state.isInversed,
                params_.poolCreation.poolKey,
                params_.vaultCreation.oracle,
                params_.vaultCreation.maxSlippage
            );

            bytes memory initManagementPayload = abi.encode(
                params_.vaultCreation.oracle,
                params_.vaultCreation.maxDeviation,
                params_.vaultCreation.cooldownPeriod,
                params_.safe,
                params_.vaultCreation.stratAnnouncer,
                params_.vaultCreation.maxSlippage
            );

            state.payload = abi.encodeWithSelector(
                IArrakisMetaVaultFactory.deployPrivateVault.selector,
                params_.vaultCreation.salt,
                state.token0,
                state.token1,
                params_.safe,
                params_.vaultCreation.upgradeableBeacon,
                moduleCreationPayload,
                initManagementPayload
            );

            bytes memory returnData;

            (state.success, returnData) = ISafe(params_.safe)
                .execTransactionFromModuleReturnData(
                factory, 0, state.payload, Operation.Call
            );

            if (!state.success) {
                revert VaultCreationErr();
            }

            vault = abi.decode(returnData, (address));
        }

        // #endregion create modular vault.

        // #region whitelist safe as depositor.

        {
            address[] memory depositors = new address[](1);
            depositors[0] = params_.safe;

            state.payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.whitelistDepositors.selector,
                depositors
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                vault, 0, state.payload, Operation.Call
            );

            if (!state.success) {
                revert WhitelistDepositorErr();
            }
        }

        // #endregion whitelist safe as depositor.

        // #region deposit into the vault.

        {
            address module =
                address(IArrakisMetaVault(vault).module());

            if (state.amount0 > 0 && state.token0 != NATIVE_COIN) {
                state.payload = abi.encodeWithSelector(
                    IERC20.approve.selector, module, state.amount0
                );

                bytes memory returnData;

                (state.success, returnData) = ISafe(params_.safe)
                    .execTransactionFromModuleReturnData(
                    state.token0, 0, state.payload, Operation.Call
                );

                if (!state.success) {
                    revert Approval0Err();
                }

                if (returnData.length > 0) {
                    bool transferSuccessful =
                        abi.decode(returnData, (bool));

                    if (!transferSuccessful) {
                        revert Approval0Err();
                    }
                }
            }

            if (state.amount1 > 0 && state.token1 != NATIVE_COIN) {
                state.payload = abi.encodeWithSelector(
                    IERC20.approve.selector, module, state.amount1
                );

                bytes memory returnData;

                (state.success, returnData) = ISafe(params_.safe)
                    .execTransactionFromModuleReturnData(
                    state.token1, 0, state.payload, Operation.Call
                );

                if (!state.success) {
                    revert Approval1Err();
                }

                if (returnData.length > 0) {
                    bool transferSuccessful =
                        abi.decode(returnData, (bool));

                    if (!transferSuccessful) {
                        revert Approval1Err();
                    }
                }
            }

            state.payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.deposit.selector,
                state.amount0,
                state.amount1
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                vault, state.value, state.payload, Operation.Call
            );

            if (!state.success) {
                revert DepositErr();
            }
        }

        // #endregion deposit into the vault.

        // #region rebalance as executor.

        if (params_.rebalancePayloads.length > 0) {
            state.payload = abi.encodeWithSelector(
                IArrakisStandardManager.rebalance.selector,
                vault,
                params_.rebalancePayloads
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                manager, 0, state.payload, Operation.Call
            );

            if (!state.success) {
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
            ) = IArrakisStandardManager(manager).vaultInfo(vault);

            SetupParams memory setupParams = SetupParams({
                vault: vault,
                oracle: oracle,
                maxDeviation: maxDeviation,
                cooldownPeriod: cooldownPeriod,
                executor: params_.executor,
                stratAnnouncer: stratAnnouncer,
                maxSlippagePIPS: maxSlippagePIPS
            });

            state.payload = abi.encodeWithSelector(
                IArrakisStandardManager.updateVaultInfo.selector,
                setupParams
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                manager, 0, state.payload, Operation.Call
            );

            if (!state.success) {
                revert ChangeExecutorErr();
            }
        }

        // #endregion change executor.

        // #region unable the module.

        {
            state.payload = abi.encodeWithSelector(
                ISafe.disableModule.selector,
                address(0x1), // SENTINEL_MODULES.
                address(this)
            );

            state.success = ISafe(params_.safe)
                .execTransactionFromModule(
                params_.safe, 0, state.payload, Operation.Call
            );

            if (!state.success) {
                revert UnableModuleErr();
            }
        }

        // #endregion unable the module.
    }

    receive() external payable {}
}
