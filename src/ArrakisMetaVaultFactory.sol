// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

import {IArrakisMetaVaultFactory} from "./interfaces/IArrakisMetaVaultFactory.sol";
import {ArrakisMetaVaultPublic} from "./ArrakisMetaVaultPublic.sol";
import {ArrakisMetaVaultPrivate} from "./ArrakisMetaVaultPrivate.sol";
import {IArrakisStandardManager} from "./interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";

import {Create3} from "@create3/contracts/Create3.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

/// @dev this contract will use create3 to deploy vaults.
contract ArrakisMetaVaultFactory is
    IArrakisMetaVaultFactory,
    Pausable,
    Ownable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region immutable properties.

    address public immutable manager;
    address public immutable moduleRegistry;

    // #endregion immutable properties.

    // #region internal properties.

    EnumerableSet.AddressSet internal _publicVaults;
    EnumerableSet.AddressSet internal _privateVaults;

    EnumerableSet.AddressSet internal _deployers;

    // #endregion internal properties.

    constructor(address owner_, address manager_, address moduleRegistry_) {
        if (
            owner_ == address(0) ||
            manager_ == address(0) ||
            moduleRegistry_ == address(0)
        ) revert AddressZero();

        _initializeOwner(owner_);
        manager = manager_;
        moduleRegistry = moduleRegistry_;
    }

    // #region owner functions.

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // #endregion owner functions.

    /// @notice function used to deploy ERC20 token wrapped Arrakis
    /// Meta Vault.
    /// @param salt_ bytes32 needed to compute vault address deterministic way.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param module_ address of the initial module that will be used
    /// by Meta Vault.
    /// @return vault address of the newly created Token Meta Vault.
    function deployPublicVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address module_,
        bytes calldata initManagementPayload_
    ) external whenNotPaused returns (address vault) {
        // #region check only deployer can create public vault.

        if (!_deployers.contains(msg.sender)) revert NotADeployer();

        // #endregion check only deployer can create public vault.

        string memory name = "Arrakis Modular Vault";
        string memory symbol = "AMV";

        try this.getTokenName(token0_, token1_) returns (string memory result) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks

        try this.getTokenSymbol(token0_, token1_) returns (
            string memory result
        ) {
            symbol = result;
        } catch {} // solhint-disable-line no-empty-blocks

        // #region compute salt = salt + msg.sender.

        // TODO maybe we need to modify that if we deploy through an helper contract.
        bytes32 salt = keccak256(abi.encode(msg.sender, salt_));

        // #endregion compute salt = salt + msg.sender.

        // #region get the creation code for TokenMetaVault.

        bytes memory creationCode = abi.encodePacked(
            type(ArrakisMetaVaultPublic).creationCode,
            abi.encode(
                token0_,
                token1_,
                owner_,
                module_,
                name,
                symbol,
                moduleRegistry,
                manager
            )
        );

        // #endregion get the creation code for TokenMetaVault.

        vault = Create3.create3(salt, creationCode);
        _publicVaults.add(vault);

        _initManagement(vault, initManagementPayload_);

        emit LogPublicVaultCreation(
            msg.sender,
            salt_,
            token0_,
            token1_,
            owner_,
            module_,
            vault
        );
    }

    /// @notice function used to deploy owned Arrakis
    /// Meta Vault (private).
    /// @param salt_ bytes32 needed to compute vault address deterministic way.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param module_ address of the initial module that will be used
    /// by Meta Vault.
    /// @return vault address of the newly created Private Meta Vault.
    function deployPrivateVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address module_,
        bytes calldata initManagementPayload_
    ) external whenNotPaused returns (address vault) {
        // #region compute salt = salt + msg.sender.

        bytes32 salt = keccak256(abi.encode(msg.sender, salt_));

        // #endregion compute salt = salt + msg.sender.

        // #region get the creation code for TokenMetaVault.

        bytes memory creationCode = abi.encodePacked(
            type(ArrakisMetaVaultPrivate).creationCode,
            abi.encode(
                token0_,
                token1_,
                owner_,
                module_,
                moduleRegistry,
                manager
            )
        );

        // #endregion get the creation code for TokenMetaVault.

        vault = Create3.create3(salt, creationCode);
        _privateVaults.add(vault);

        _initManagement(vault, initManagementPayload_);

        emit LogPrivateVaultCreation(
            msg.sender,
            salt_,
            token0_,
            token1_,
            owner_,
            module_,
            vault
        );
    }

    function whitelistDeployer(
        address[] calldata deployers_
    ) external onlyOwner {
        uint256 length = deployers_.length;

        for (uint256 i; i < length; i++) {
            address deployer = deployers_[i];

            if (deployer == address(0)) revert AddressZero();
            if (_deployers.contains(deployer))
                revert AlreadyWhitelistedDeployer(deployer);

            _deployers.add(deployer);
        }

        emit LogWhitelistDeployers(deployers_);
    }

    function blacklistDeployer(
        address[] calldata deployers_
    ) external onlyOwner {
        uint256 length = deployers_.length;

        for (uint256 i; i < length; i++) {
            address deployer = deployers_[i];

            if (deployer == address(0)) revert AddressZero();
            if (_deployers.contains(deployer))
                revert NotAlreadyADeployer(deployer);

            _deployers.remove(deployer);
        }

        emit LogBlacklistDeployers(deployers_);
    }

    // #region view/pure function.

    /// @notice get Arrakis Modular standard token name for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return name name of the arrakis modular token vault.
    function getTokenName(
        address token0_,
        address token1_
    ) public view returns (string memory) {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return _append("Arrakis Modular ", symbol0, "/", symbol1);
    }

    /// @notice get Arrakis Modular standard token symbol for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return symbol symbol of the arrakis modular token vault.
    function getTokenSymbol(
        address token0_,
        address token1_
    ) public view returns (string memory) {
        string memory symbol0 = IERC20Metadata(token0_).symbol();
        string memory symbol1 = IERC20Metadata(token1_).symbol();
        return string(abi.encodePacked("AM/", symbol0, "/", symbol1));
    }

    /// @notice get a list of public vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function publicVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory) {
        if (startIndex_ >= endIndex_)
            revert StartIndexLtEndIndex(startIndex_, endIndex_);

        uint256 vaultsLength = numOfPublicVaults();
        if (endIndex_ > vaultsLength)
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _publicVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfPublicVaults counts the total number of public vaults in existence
    /// @return result total number of vaults deployed
    function numOfPublicVaults() public view returns (uint256 result) {
        return _publicVaults.length();
    }

    /// @notice get a list of private vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function privateVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory) {
        if (startIndex_ >= endIndex_)
            revert StartIndexLtEndIndex(startIndex_, endIndex_);

        uint256 vaultsLength = numOfPrivateVaults();
        if (endIndex_ > vaultsLength)
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _privateVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfPrivateVaults counts the total number of private vaults in existence
    /// @return result total number of vaults deployed
    function numOfPrivateVaults() public view returns (uint256 result) {
        return _privateVaults.length();
    }

    function deployers() external view returns (address[] memory) {
        return _deployers.values();
    }

    // #endregion view/pure functions.

    // #region internal functions.

    function _append(
        string memory a_,
        string memory b_,
        string memory c_,
        string memory d_
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a_, b_, c_, d_));
    }

    function _initManagement(address vault_, bytes memory data_) internal {
        bytes memory data = abi.encodeWithSelector(
            IArrakisStandardManager.initManagement.selector,
            data_
        );
        (bool success, ) = manager.call(data);

        if (!success) revert CallFailed();

        if (!IArrakisStandardManager(manager).isManaged(vault_))
            revert VaultNotManaged();
    }

    // #endregion internal functions.
}
