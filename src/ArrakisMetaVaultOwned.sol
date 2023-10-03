// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaOwned} from "./interfaces/IArrakisMetaOwned.sol";
import {ArrakisMetaVault} from "./ArrakisMetaVault.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

error NotImplemented();
error MintZero();
error BurnZero();
error BurnOverflow();

contract ArrakisMetaVaultOwned is ArrakisMetaVault, IArrakisMetaOwned {
    constructor(
        address token0_,
        address token1_,
        address owner_,
        uint256 init0_,
        uint256 init1_,
        address module_
    ) ArrakisMetaVault(token0_, token1_, owner_, init0_, init1_, module_) {}

    function deposit(
        uint256 proportion_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _deposit(proportion_);
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _withdraw(proportion_);

        if (amount0 > 0) IERC20(token0).transfer(receiver_, amount0);
        if (amount1 > 0) IERC20(token1).transfer(receiver_, amount1);
    }
}
