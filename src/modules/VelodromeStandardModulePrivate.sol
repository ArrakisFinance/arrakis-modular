// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {AerodromeStandardModulePrivate} from "./AerodromeStandardModulePrivate.sol";

contract VelodromeStandardModulePrivate is
    AerodromeStandardModulePrivate
{
    constructor(
        address nftPositionManager_,
        address factory_,
        address voter_,
        address guardian_
    ) AerodromeStandardModulePrivate(nftPositionManager_, factory_, voter_, guardian_) {
        AERO = 0x9560e827aF36c94D2Ac33a39bCE1Fe78631088Db; // VELO address
    }
}
