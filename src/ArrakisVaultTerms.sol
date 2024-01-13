// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisVaultTerms} from "./interfaces/IArrakisVaultTerms.sol";
import {IOwnerOf} from "./interfaces/IOwnerOf.sol";
import {IArrakisMetaVaultFactory} from "./interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisMetaVaultPrivate} from "./interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";

import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract ArrakisVaultTerms is IArrakisVaultTerms, IOwnerOf, Ownable {
    using SafeERC20 for IERC20;

    // #region public immutable properties.

    address public immutable nativeToken;

    // #endregion public immutable properties.

    // #region public properties.

    address public arrakisMetaVaultFactory;
    mapping(address => address) ownerByVault;

    // #endregion public properties.

    // #region modifiers.

    modifier OnlyVaultOwner(address vault_) {
        address o = ownerByVault[vault_];
        if (msg.sender != o) revert NotOwner(msg.sender, o);
        _;
    }

    // #endregion modifiers.

    constructor(address owner_, address nativeToken_) {
        if (owner_ == address(0) || nativeToken_ == address(0))
            revert AddressZero();
        _initializeOwner(owner_);
        nativeToken = nativeToken_;
    }

    // #region only owner functions.

    function setArrakisMetaVaultFactory(
        address arrakisMetaVaultFactory_
    ) external onlyOwner {
        if (arrakisMetaVaultFactory != address(0))
            revert ArrakisMetaVaultFactoryAlreadySet();
        if (arrakisMetaVaultFactory_ == address(0)) revert AddressZero();

        arrakisMetaVaultFactory = arrakisMetaVaultFactory_;
        emit LogSetArrakisMetaVaultFactory(arrakisMetaVaultFactory_);
    }

    // #endregion only owner functions.

    function createVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
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

        // #endregion create the owned vault.

        ownerByVault[vault] = owner_;

        emit LogCreate(
            salt_,
            msg.sender,
            token0_,
            token1_,
            owner_,
            module_,
            vault
        );
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

    function setManager(
        address vault_,
        address newManager_
    ) external OnlyVaultOwner(vault_) {
        IArrakisMetaVault(vault_).setManager(newManager_);

        emit LogSetManager(msg.sender, newManager_);
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

    function ownerOf(address vault_) external view returns (address owner) {
        owner = ownerByVault[vault_];
    }

    function getTokenIdFromVaultAddr(
        address vault_
    ) public pure returns (uint256 tokenID) {
        return uint256(uint160(vault_));
    }

    // #endregion view/pure functions.
}
