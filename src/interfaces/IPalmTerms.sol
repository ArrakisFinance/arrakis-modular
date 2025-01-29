// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisV2} from "./IArrakisV2.sol";

interface IPalmTerms {
    function closeTerm(
        IArrakisV2 vault_,
        address to_,
        address newOwner_,
        address newManager_
    ) external;
}