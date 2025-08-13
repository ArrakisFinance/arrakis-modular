// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

contract MetaVault {
    uint256 public totalSupply;
    IArrakisLPModule public module;

    function setTotalSupply(
        uint256 totalSupply_
    ) external {
        totalSupply = totalSupply_;
    }

    function setModule(
        IArrakisLPModule module_
    ) external {
        module = module_;
    }
}
