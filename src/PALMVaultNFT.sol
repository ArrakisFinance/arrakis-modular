// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IPALMVaultNFT} from "./interfaces/IPALMVaultNFT.sol";
import {IArrakisMetaVaultFactory} from "./interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisMetaVaultPrivate} from "./interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisStandardManager} from "./interfaces/IArrakisStandardManager.sol";
import {SetupParams} from "./structs/SManager.sol";

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

contract PALMVaultNFT is IPALMVaultNFT, ERC721 {
    using SafeERC20 for IERC20;

    // #region public immutable properties.

    address public immutable nativeToken;
    address public immutable arrakisMetaVaultFactory;
    address public immutable arrakisStandardManager;

    // #endregion public immutable properties.

    // #region public properties.


    // #endregion public properties.

    // #region modifiers.

    modifier OnlyVaultOwner(address vault_) {
        address o = ownerOf(uint256(uint160(vault_)));
        if (msg.sender != o) revert NotOwner(msg.sender, o);
        _;
    }

    // #endregion modifiers.

    constructor(
        address nativeToken_,
        address vaultFactory_,
        address manager_
    ) ERC721("Arrakis Modular PALM Vaults", "PALM") {
        if (
            nativeToken_ == address(0) ||
            vaultFactory_ == address(0) ||
            manager_ == address(0)
        ) revert AddressZero();
        nativeToken = nativeToken_;
        arrakisMetaVaultFactory = vaultFactory_;
        arrakisStandardManager = manager_;
    }

    // #endregion only owner functions.

    function mint(
        bytes32 salt_,
        address token0_,
        address token1_,
        address receiver_,
        address module_
    ) external {
        if (module_ == address(0)) revert AddressZero();

        // #region compute custom salt.

        bytes32 _salt = keccak256(abi.encode(msg.sender, salt_));

        // #endregion compute custom salt.

        // #region create the owned vault.

        address vault = IArrakisMetaVaultFactory(arrakisMetaVaultFactory)
            .deployPrivateVault(
                _salt,
                token0_,
                token1_,
                address(this), // NFT contract will be the owner.
                module_
            );

        uint256 tokenId = uint256(uint160(vault));

        // #endregion create the owned vault.

        _mint(receiver_, tokenId);

        emit LogMint(
            salt_,
            msg.sender,
            token0_,
            token1_,
            receiver_,
            module_,
            tokenId,
            vault
        );
    }

    function initManagement(
        SetupParams calldata params_
    ) external OnlyVaultOwner(params_.vault) {
        IArrakisMetaVault(params_.vault).setManager(arrakisStandardManager);

        IArrakisStandardManager(arrakisStandardManager).initManagement(params_);
    }

    function updateVaultManagement(
        SetupParams calldata params_
    ) external OnlyVaultOwner(params_.vault) {
        IArrakisStandardManager(arrakisStandardManager).updateVaultInfo(params_);
    }

    function deposit(
        address vault_,
        uint256 proportion_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        external
        payable
        OnlyVaultOwner(vault_)
        returns (uint256 amount0, uint256 amount1)
    {
        IERC20 _token0 = IERC20(IArrakisMetaVault(vault_).token0());
        IERC20 _token1 = IERC20(IArrakisMetaVault(vault_).token1());

        address module = address(IArrakisMetaVault(vault_).module());

        // #region interactions.

        if (address(_token0) == nativeToken) {
            if (msg.value != maxAmount0_)
                revert ValueDtMaxAmount(msg.value, maxAmount0_);
        } else {
            _token0.safeTransferFrom(msg.sender, address(this), maxAmount0_);
            _token0.safeIncreaseAllowance(module, maxAmount0_);
        }
        if (address(_token1) == nativeToken) {
            if (msg.value != maxAmount1_)
                revert ValueDtMaxAmount(msg.value, maxAmount1_);
        } else {
            _token1.safeTransferFrom(msg.sender, address(this), maxAmount1_);
            _token1.safeIncreaseAllowance(module, maxAmount1_);
        }

        (amount0, amount1) = IArrakisMetaVaultPrivate(vault_).deposit{
            value: msg.value
        }(proportion_);

        uint256 leftOver0 = maxAmount0_ - amount0;
        uint256 leftOver1 = maxAmount1_ - amount1;

        if (leftOver0 > 0) {
            if (address(_token0) != nativeToken)
                _token0.safeTransfer(msg.sender, leftOver0);
            else Address.sendValue(payable(msg.sender), leftOver0);
        }
        if (leftOver1 > 0) {
            if (address(_token1) != nativeToken)
                _token1.safeTransfer(msg.sender, leftOver1);
            else Address.sendValue(payable(msg.sender), leftOver1);
        }

        // #endregion interactions.

        emit LogDeposit(msg.sender, proportion_, amount0, amount1);
    }

    function withdraw(
        address vault_,
        uint256 proportion_,
        address receiver_
    )
        external
        OnlyVaultOwner(vault_)
        returns (uint256 amount0, uint256 amount1)
    {
        // #region interactions.

        (amount0, amount1) = IArrakisMetaVaultPrivate(vault_).withdraw(
            proportion_,
            receiver_
        );

        // #endregion interactions.

        emit LogWithdraw(msg.sender, proportion_, amount0, amount1);
    }

    function whitelistModules(
        address vault_,
        address[] calldata modules_
    ) external OnlyVaultOwner(vault_) {
        IArrakisMetaVault(vault_).whitelistModules(modules_);

        emit LogWhiteListedModules(msg.sender, modules_);
    }

    function blacklistModules(
        address vault_,
        address[] calldata modules_
    ) external OnlyVaultOwner(vault_) {
        IArrakisMetaVault(vault_).blacklistModules(modules_);

        emit LogBlackListedModules(msg.sender, modules_);
    }

    // #region view/pure functions.

    function getTokenIdFromVaultAddr(
        address vault_
    ) public pure returns (uint256 tokenID) {
        return uint256(uint160(vault_));
    }

    // #endregion view/pure functions.
}
