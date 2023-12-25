// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaOwned} from "./interfaces/IArrakisMetaOwned.sol";
import {ArrakisMetaVault} from "./ArrakisMetaVault.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArrakisMetaVaultOwned is ArrakisMetaVault, IArrakisMetaOwned {
    constructor(
        address token0_,
        address token1_,
        address owner_,
        address module_
    ) ArrakisMetaVault(token0_, token1_, owner_, module_) {}

    function deposit(
        uint256 proportion_
    ) external payable onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _deposit(proportion_);
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _withdraw(receiver_, proportion_);
    }
}
