// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IOwnable} from "../../../../src/interfaces/IOwnable.sol";
import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

import {LpModuleMock} from "./LpModuleMock.sol";

contract ArrakisMetaVaultMock is IOwnable {
    address public _owner;

    IArrakisLPModule public module;
    address public manager;

    IERC20 public token0;
    IERC20 public token1;

    function setTokenOAndToken1(
        address token0_,
        address token1_
    ) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setModule(address module_) external {
        module = IArrakisLPModule(module_);
    }

    function setModule(address module_, bytes[] calldata) external {
        module = IArrakisLPModule(module_);
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setOwner(address owner_) external {
        _owner = owner_;
    }

    function owner() external view returns (address) {
        return _owner;
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return module.totalUnderlying();
    }
}
