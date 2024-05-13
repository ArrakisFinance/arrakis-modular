// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ICreationCode} from "./interfaces/ICreationCode.sol";
import {ArrakisMetaVaultPrivate} from "./ArrakisMetaVaultPrivate.sol";

contract CreationCodePrivateVault is ICreationCode {
    function getCreationCode() external pure returns (bytes memory) {
        return type(ArrakisMetaVaultPrivate).creationCode;
    }
}
