// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {ICreationCode} from "./interfaces/ICreationCode.sol";
import {ArrakisMetaVaultPublic} from "./ArrakisMetaVaultPublic.sol";

contract CreationCodePublicVault is ICreationCode {
    function getCreationCode() external pure returns (bytes memory) {
        return type(ArrakisMetaVaultPublic).creationCode;
    }
}
