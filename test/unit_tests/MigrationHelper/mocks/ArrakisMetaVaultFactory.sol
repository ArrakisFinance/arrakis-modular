// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

contract ArrakisMetaVaultFactoryMock {
    function deployPrivateVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address beacon_,
        bytes calldata moduleCreationPayload_,
        bytes calldata initManagementPayload_
    ) external returns (address vault) {
        return address(new ArrakisMetaVaultMock());
    }
}

contract ArrakisMetaVaultMock {
    IArrakisLPModule public module;
}
