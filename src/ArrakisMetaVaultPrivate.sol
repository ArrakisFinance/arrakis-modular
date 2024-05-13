// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisMetaVaultPrivate} from
    "./interfaces/IArrakisMetaVaultPrivate.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {ArrakisMetaVault} from "./abstracts/ArrakisMetaVault.sol";
import {IArrakisLPModulePrivate} from
    "./interfaces/IArrakisLPModulePrivate.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ArrakisMetaVaultPrivate is
    ArrakisMetaVault,
    IArrakisMetaVaultPrivate,
    IOwnable
{
    using Address for address payable;
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region immutable properties.

    address public immutable nft;

    // #endregion immutable properties.

    // #region internal properties.

    EnumerableSet.AddressSet internal _depositors;

    // #endregion internal properties.

    constructor(
        address moduleRegistry_,
        address manager_,
        address token0_,
        address token1_,
        address nft_
    ) ArrakisMetaVault(moduleRegistry_, manager_, token0_, token1_) {
        if (nft_ == address(0)) revert AddressZero("NFT");
        nft = nft_;
    }

    /// @notice function used to deposit tokens or expand position inside the
    /// inherent strategy.
    /// @param amount0_ amount of token0 need to increase the position by proportion_;
    /// @param amount1_ amount of token1 need to increase the position by proportion_;
    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable {
        // NOTE: should we also allow owner to be a depositor by default?
        if (!_depositors.contains(msg.sender)) revert OnlyDepositor();
        _deposit(amount0_, amount1_);

        emit LogDeposit(amount0_, amount1_);
    }

    /// @notice function used to withdraw tokens or position contraction of the
    /// underpin strategy.
    /// @param proportion_ the proportion of position contraction.
    /// @param receiver_ the address that will receive withdrawn tokens.
    /// @return amount0 amount of token0 returned.
    /// @return amount1 amount of token1 returned.
    function withdraw(
        uint256 proportion_,
        address receiver_
    )
        external
        onlyOwnerCustom
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = _withdraw(receiver_, proportion_);

        emit LogWithdraw(proportion_, amount0, amount1);
    }

    /// @notice function used to whitelist depositors.
    /// @param depositors_  list of address that will be granted to depositor role.
    function whitelistDepositors(address[] calldata depositors_)
        external
        onlyOwnerCustom
    {
        uint256 length = depositors_.length;
        for (uint256 i; i < length; i++) {
            address depositor = depositors_[i];

            if (depositor == address(0)) {
                revert AddressZero("Depositor");
            }
            if (_depositors.contains(depositor)) {
                revert DepositorAlreadyWhitelisted();
            }

            _depositors.add(depositor);
        }

        emit LogWhitelistDepositors(depositors_);
    }

    /// @notice function used to blacklist depositors.
    /// @param depositors_ list of address who depositor role will be revoked.
    function blacklistDepositors(address[] calldata depositors_)
        external
        onlyOwnerCustom
    {
        uint256 length = depositors_.length;
        for (uint256 i; i < length; i++) {
            address depositor = depositors_[i];

            if (!_depositors.contains(depositor)) {
                revert NotAlreadyWhitelistedDepositor();
            }

            _depositors.remove(depositor);
        }

        emit LogBlacklistDepositors(depositors_);
    }

    // #region external view/pure functions.

    /// @notice function used to get the owner of this contract.
    function owner() external view returns (address) {
        return IERC721(nft).ownerOf(uint256(uint160(address(this))));
    }

    /// @notice function used to get the list of depositors.
    /// @return depositors list of address granted to depositor role.
    function depositors() external view returns (address[] memory) {
        return _depositors.values();
    }

    // #endregion  external view/pure functions.

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

        payable(address(module)).functionCallWithValue(
            data, msg.value
        );
    }

    function _onlyOwnerCheck() internal view override {
        if (
            msg.sender
                != IERC721(nft).ownerOf(uint256(uint160(address(this))))
        ) {
            revert OnlyOwner();
        }
    }

    // #endregion internal functions.
}
