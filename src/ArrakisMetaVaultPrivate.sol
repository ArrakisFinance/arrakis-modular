// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisMetaVaultPrivate} from "./interfaces/IArrakisMetaVaultPrivate.sol";
import {ArrakisMetaVault} from "./abstracts/ArrakisMetaVault.sol";

import {PRIVATE_TYPE} from "./constants/CArrakis.sol";

contract ArrakisMetaVaultPrivate is ArrakisMetaVault, IArrakisMetaVaultPrivate {
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

    /// @notice function used to get the type of vault.
    function vaultType() external pure returns (bytes32) {
        return PRIVATE_TYPE;
    }
}
