// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisMetaVaultPrivate} from "./interfaces/IArrakisMetaVaultPrivate.sol";
import {ArrakisMetaVault} from "./abstracts/ArrakisMetaVault.sol";
import {IArrakisLPModulePrivate} from "./interfaces/IArrakisLPModulePrivate.sol";
import {PRIVATE_TYPE} from "./constants/CArrakis.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract ArrakisMetaVaultPrivate is ArrakisMetaVault, IArrakisMetaVaultPrivate {
    using Address for address payable;

    // #region immutable properties.

    address public immutable nft;

    // #endregion immutable properties.

    constructor(
        address token0_,
        address token1_,
        address moduleRegistry_,
        address manager_,
        address nft_
    ) ArrakisMetaVault(token0_, token1_, moduleRegistry_, manager_) {
        nft = nft_;
    }

    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyOwnerCustom {
        _deposit(amount0_, amount1_);
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external onlyOwnerCustom returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _withdraw(receiver_, proportion_);
    }

    /// @notice function used to get the type of vault.
    function vaultType() external pure returns (bytes32) {
        return PRIVATE_TYPE;
    }

    // #region internal functions.

    function _deposit(
        uint256 amount0_,
        uint256 amount1_
    ) internal nonReentrant {
        /// @dev msg.sender should be the tokens provider

        bytes memory data = abi.encodeWithSelector(
            IArrakisLPModulePrivate.fund.selector,
            msg.sender,
            amount0_,
            amount1_
        );

        payable(address(module)).functionCallWithValue(data, msg.value);

        emit LogDeposit(amount0_, amount1_);
    }

    function onlyOwnerCheck() public view override {
        if (msg.sender != IERC721(nft).ownerOf(uint256(uint160(address(this)))))
            revert OnlyOwner();
    }

    // #endregion internal functions.
}