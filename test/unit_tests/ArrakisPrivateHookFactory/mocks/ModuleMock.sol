// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IArrakisMetaVault} from
    "../../../../src/interfaces/IArrakisMetaVault.sol";

contract ModuleMock {
    IArrakisMetaVault public metaVault;

    constructor() {
        metaVault = IArrakisMetaVault(address(new MetaVault()));
    }
}

contract MetaVault {
    address public manager;

    constructor() {
        address manager = address(1);
    }
}
