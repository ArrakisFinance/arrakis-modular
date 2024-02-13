// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOwnable} from "../../../../src/interfaces/IOwnable.sol";

contract ArrakisMetaVaultMock is IOwnable {

    address public _owner;

    address public module;
    address public manager;

    IERC20 public token0;
    IERC20 public token1;

    function setTokenOAndToken1(address token0_, address token1_) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setModule(address module_) external {
        module = module_;
    }

    function setModule(address module_, bytes[] calldata) external {
        module = module_;
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setOwner(address owner_) external {
        _owner = owner_;
    }

    function owner() external view returns(address) {
        return _owner;
    }
}
