// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisMetaVault} from 
    "../../../../src/interfaces/IArrakisMetaVault.sol";

contract ArrakisLPModuleMock {

    IArrakisMetaVault public metaVault;

    function setVault(address metaVault_) external {
        metaVault = IArrakisMetaVault(metaVault_);
    }
}