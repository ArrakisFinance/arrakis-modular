// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

contract ArrakisMetaVaultMock {
    address public manager;
    address public owner;
    address public token0;
    address public token1;
    uint256 public totalSupply;
    IArrakisLPModule public module;

    constructor(address manager_, address owner_) {
        manager = manager_;
        owner = owner_;
    }

    // #region mock functions.

    function setManager(
        address manager_
    ) external {
        manager = manager_;
    }

    function setTokens(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

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

    // #endregion mock functions.
}
