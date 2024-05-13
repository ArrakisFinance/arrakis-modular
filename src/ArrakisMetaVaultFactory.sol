// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";

import {IArrakisMetaVaultFactory} from
    "./interfaces/IArrakisMetaVaultFactory.sol";
import {ICreationCode} from "./interfaces/ICreationCode.sol";
import {IManager} from "./interfaces/IManager.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IModuleRegistry} from "./interfaces/IModuleRegistry.sol";
import {TimeLock} from "./TimeLock.sol";
import {PALMVaultNFT} from "./PALMVaultNFT.sol";

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

    address public immutable moduleRegistryPublic;
    address public immutable moduleRegistryPrivate;
    address public immutable creationCodePublicVault;
    address public immutable creationCodePrivateVault;
    PALMVaultNFT public immutable nft;

    // #endregion immutable properties.

    address public manager;

    // #region internal properties.

    EnumerableSet.AddressSet internal _publicVaults;
    EnumerableSet.AddressSet internal _privateVaults;

    EnumerableSet.AddressSet internal _deployers;

    // #endregion internal properties.

    constructor(
        address owner_,
        address manager_,
        address moduleRegistryPublic_,
        address moduleRegistryPrivate_,
        address creationCodePublicVault_,
        address creationCodePrivateVault_
    ) {
        if (
            owner_ == address(0) || manager_ == address(0)
                || moduleRegistryPublic_ == address(0)
                || moduleRegistryPrivate_ == address(0)
                || creationCodePublicVault_ == address(0)
                || creationCodePrivateVault_ == address(0)
        ) revert AddressZero();

        _initializeOwner(owner_);
        manager = manager_;
        moduleRegistryPublic = moduleRegistryPublic_;
        moduleRegistryPrivate = moduleRegistryPrivate_;
        creationCodePublicVault = creationCodePublicVault_;
        creationCodePrivateVault = creationCodePrivateVault_;
        nft = new PALMVaultNFT();
    }

    // #region pausable functions.

    /// @notice function used to pause the factory.
    /// @dev only callable by owner.
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    /// @notice function used to unpause the factory.
    /// @dev only callable by owner.
    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    // #endregion pausable functions.

    // #region set manager.

    /// @notice function used to set a new manager.
    /// @param newManager_ address that will managed newly created vault.
    /// @dev only callable by owner.
    function setManager(address newManager_) external onlyOwner {
        address oldManager = manager;

        if (newManager_ == address(0)) revert AddressZero();
        if (newManager_ == oldManager) revert SameManager();

        manager = newManager_;

        emit LogSetManager(oldManager, newManager_);
    }

    // #endregion set manager.

    /// @notice function used to deploy ERC20 token wrapped Arrakis
    /// Meta Vault.
    /// @param salt_ bytes32 used to get a deterministic all chains address.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param beacon_ address of the beacon that will be used to create the default module.
    /// @param moduleCreationPayload_ payload for initializing the module.
    /// @param initManagementPayload_ data for initialize management.
    /// @return vault address of the newly created Token Meta Vault.
    function deployPublicVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address beacon_,
        bytes calldata moduleCreationPayload_,
        bytes calldata initManagementPayload_
    ) external whenNotPaused returns (address vault) {
        // #region check only deployer can create public vault.

        if (!_deployers.contains(msg.sender)) revert NotADeployer();

        // #endregion check only deployer can create public vault.

        // #region create timeLock.

        address timeLock;

        {
            address[] memory proposers = new address[](1);
            address[] memory executors = new address[](1);

            proposers[0] = owner_;
            executors[0] = owner_;

            // NOTE let's create3 timelock or remove create3 for public vault.
            timeLock = address(
                new TimeLock(2 days, proposers, executors, owner_)
            );
        }

        // #endregion create timeLock.

        {
            // #region get the creation code for TokenMetaVault.
            bytes memory creationCode = abi.encodePacked(
                ICreationCode(creationCodePublicVault).getCreationCode(
                ),
                _getPublicVaultConstructorPayload(
                    timeLock, token0_, token1_
                )
            );

            bytes32 salt = keccak256(abi.encode(msg.sender, salt_));

            // #endregion get the creation code for TokenMetaVault.
            vault = Create3.create3(salt, creationCode);
        }

        _publicVaults.add(vault);

        // #region create a module.
        address module;

        {
            bytes memory moduleCreationPayload = abi.encodePacked(
                moduleCreationPayload_,
                bytes32(uint256(uint160(vault)))
            );

            module = IModuleRegistry(moduleRegistryPublic)
                .createModule(vault, beacon_, moduleCreationPayload);
        }

        // #endregion create a module.

        IArrakisMetaVault(vault).initialize(module);

        _initManagement(vault, initManagementPayload_);

        emit LogPublicVaultCreation(
            msg.sender,
            salt_,
            token0_,
            token1_,
            owner_,
            module,
            vault,
            timeLock
        );
    }

    /// @notice function used to deploy owned Arrakis
    /// Meta Vault.
    /// @param salt_ bytes32 needed to compute vault address deterministic way.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param beacon_ address of the beacon that will be used to create the default module.
    /// @param moduleCreationPayload_ payload for initializing the module.
    /// @param initManagementPayload_ data for initialize management.
    /// @return vault address of the newly created private Meta Vault.
    function deployPrivateVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address beacon_,
        bytes calldata moduleCreationPayload_,
        bytes calldata initManagementPayload_
    ) external whenNotPaused returns (address vault) {
        // #region compute salt = salt + msg.sender.

        bytes32 salt = keccak256(abi.encode(msg.sender, salt_));

        // #endregion compute salt = salt + msg.sender.

        // #region get the creation code for TokenMetaVault.

        bytes memory creationCode = abi.encodePacked(
            ICreationCode(creationCodePrivateVault).getCreationCode(),
            abi.encode(
                moduleRegistryPrivate,
                manager,
                token0_,
                token1_,
                address(nft)
            )
        );

        // #endregion get the creation code for TokenMetaVault.

        vault = Create3.create3(salt, creationCode);
        nft.mint(owner_, uint256(uint160(vault)));
        _privateVaults.add(vault);

        // #region create a module.

        address module;

        {
            bytes memory moduleCreationPayload = abi.encodePacked(
                moduleCreationPayload_,
                bytes32(uint256(uint160(vault)))
            );

            module = IModuleRegistry(moduleRegistryPrivate)
                .createModule(vault, beacon_, moduleCreationPayload);
        }

        IArrakisMetaVault(vault).initialize(module);

        // #endregion create a module.

        _initManagement(vault, initManagementPayload_);

        emit LogPrivateVaultCreation(
            msg.sender, salt_, token0_, token1_, owner_, module, vault
        );
    }

    /// @notice function used to grant the role to deploy to a list of addresses.
    /// @param deployers_ list of addresses that owner want to grant permission to deploy.
    function whitelistDeployer(address[] calldata deployers_)
        external
        onlyOwner
    {
        uint256 length = deployers_.length;

        for (uint256 i; i < length; i++) {
            address deployer = deployers_[i];

            if (deployer == address(0)) revert AddressZero();
            if (_deployers.contains(deployer)) {
                revert AlreadyWhitelistedDeployer(deployer);
            }

            _deployers.add(deployer);
        }

        emit LogWhitelistDeployers(deployers_);
    }

    /// @notice function used to grant the role to deploy to a list of addresses.
    /// @param deployers_ list of addresses that owner want to grant permission to deploy.
    function blacklistDeployer(address[] calldata deployers_)
        external
        onlyOwner
    {
        uint256 length = deployers_.length;

        for (uint256 i; i < length; i++) {
            address deployer = deployers_[i];

            if (!_deployers.contains(deployer)) {
                revert NotAlreadyADeployer(deployer);
            }

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
        if (startIndex_ >= endIndex_) {
            revert StartIndexLtEndIndex(startIndex_, endIndex_);
        }

        uint256 vaultsLength = numOfPublicVaults();
        if (endIndex_ > vaultsLength) {
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);
        }

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _publicVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfPublicVaults counts the total number of public vaults in existence
    /// @return result total number of vaults deployed
    function numOfPublicVaults()
        public
        view
        returns (uint256 result)
    {
        return _publicVaults.length();
    }

    /// @notice isPublicVault check if the inputed vault is a public vault.
    /// @param vault_ address of the address to check.
    /// @return isPublicVault true if the inputed vault is public or otherwise false.
    function isPublicVault(address vault_)
        external
        view
        returns (bool)
    {
        return _publicVaults.contains(vault_);
    }

    /// @notice get a list of private vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function privateVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory) {
        if (startIndex_ >= endIndex_) {
            revert StartIndexLtEndIndex(startIndex_, endIndex_);
        }

        uint256 vaultsLength = numOfPrivateVaults();
        if (endIndex_ > vaultsLength) {
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);
        }

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _privateVaults.at(i);
        }

        return vs;
    }

    /// @notice numOfPrivateVaults counts the total number of private vaults in existence
    /// @return result total number of vaults deployed
    function numOfPrivateVaults()
        public
        view
        returns (uint256 result)
    {
        return _privateVaults.length();
    }

    /// @notice isPrivateVault check if the inputed vault is a private vault.
    /// @param vault_ address of the address to check.
    /// @return isPublicVault true if the inputed vault is private or otherwise false.
    function isPrivateVault(address vault_)
        external
        view
        returns (bool)
    {
        return _privateVaults.contains(vault_);
    }

    /// @notice function used to get a list of address that can deploy public vault.
    function deployers() external view returns (address[] memory) {
        return _deployers.values();
    }

    // #endregion view/pure functions.

    // #region internal functions.

    function _initManagement(
        address vault_,
        bytes memory data_
    ) internal {
        /// @dev to anticipate futur changes in the manager's initManagement function
        /// manager should implement getInitManagementSelector function, so factory can get the
        /// the right selector of the function.
        bytes4 selector =
            IManager(manager).getInitManagementSelector();

        /// @dev for initializing management we need to know the vault address,
        /// so manager should follow this pattern where vault address is the first parameter of the function.
        bytes memory data = data_.length == 0
            ? abi.encodeWithSelector(selector, vault_)
            : abi.encodePacked(
                abi.encodeWithSelector(selector, vault_), data_
            );

        (bool success,) = manager.call(data);

        if (!success) revert CallFailed();

        if (!IManager(manager).isManaged(vault_)) {
            revert VaultNotManaged();
        }
    }

    function _getPublicVaultConstructorPayload(
        address timeLock_,
        address token0_,
        address token1_
    ) internal view returns (bytes memory) {
        string memory name = "Arrakis Modular Vault";
        string memory symbol = "AMV";

        try this.getTokenName(token0_, token1_) returns (
            string memory result
        ) {
            name = result;
        } catch {} // solhint-disable-line no-empty-blocks

        try this.getTokenSymbol(token0_, token1_) returns (
            string memory result
        ) {
            symbol = result;
        } catch {} // solhint-disable-line no-empty-blocks

        return abi.encode(
            timeLock_,
            name,
            symbol,
            moduleRegistryPublic,
            manager,
            token0_,
            token1_
        );
    }

    function _append(
        string memory a_,
        string memory b_,
        string memory c_,
        string memory d_
    ) internal pure returns (string memory) {
        return string(abi.encodePacked(a_, b_, c_, d_));
    }

    // #endregion internal functions.
}
