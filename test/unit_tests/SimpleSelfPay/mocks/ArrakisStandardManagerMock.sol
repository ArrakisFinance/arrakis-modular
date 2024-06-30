// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    VaultInfo,
    SetupParams
} from "../../../../src/structs/SManager.sol";

contract ArrakisStandardManagerMock {
    VaultInfo public info;

    function updateVaultInfo(SetupParams calldata params_) external {
        VaultInfo memory i = info;

        info = VaultInfo({
            lastRebalance: i.lastRebalance,
            cooldownPeriod: params_.cooldownPeriod,
            oracle: params_.oracle,
            executor: params_.executor,
            maxDeviation: params_.maxDeviation,
            stratAnnouncer: params_.stratAnnouncer,
            maxSlippagePIPS: params_.maxSlippagePIPS,
            managerFeePIPS: i.managerFeePIPS
        });
    }

    function vaultInfo(address)
        external
        view
        returns (VaultInfo memory)
    {
        return info;
    }

    function rebalance(address, bytes[] calldata) external {}
}
