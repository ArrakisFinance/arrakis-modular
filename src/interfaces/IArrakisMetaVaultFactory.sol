// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface IArrakisMetaVaultFactory {
    // #region errors.

    error AddressZero();

    /// @dev triggered when querying vaults on factory
    /// and start index is lower than end index.
    error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);

    /// @dev triggered when querying vaults on factory
    /// and end index of the query is bigger the biggest index of the vaults array.
    error EndIndexGtNbOfVaults(
        uint256 endIndex, uint256 numberOfVaults
    );

    /// @dev triggered when owner want to whitelist a deployer that has been already
    /// whitelisted.
    error AlreadyWhitelistedDeployer(address deployer);

    /// @dev triggered when owner want to blackist a deployer that is not a current
    /// deployer.
    error NotAlreadyADeployer(address deployer);

    /// @dev triggered when public vault deploy function is
    /// called by an address that is not a deployer.
    error NotADeployer();

    /// @dev triggered when init management low level failed.
    error CallFailed();

    /// @dev triggered when init management happened and still the vault is
    /// not under management by manager.
    error VaultNotManaged();

    /// @dev triggered when owner is setting a new manager, and the new manager
    /// address match with the old manager address.
    error SameManager();

    // #endregion errors.

    // #region events.

    /// @notice event emitted when public vault is created by a deployer.
    /// @param creator address that is creating the public vault, a deployer.
    /// @param salt salt used for create3.
    /// @param token0 first token of the token pair.
    /// @param token1 second token of the token pair.
    /// @param owner address of the owner.
    /// @param module default module that will be used by the meta vault.
    /// @param publicVault address of the deployed meta vault.
    /// @param timeLock timeLock that will owned the meta vault.
    event LogPublicVaultCreation(
        address indexed creator,
        bytes32 salt,
        address token0,
        address token1,
        address owner,
        address module,
        address publicVault,
        address timeLock
    );

    /// @notice event emitted when private vault is created.
    /// @param creator address that is deploying the vault.
    /// @param salt salt used for create3.
    /// @param token0 address of the first token of the pair.
    /// @param token1 address of the second token of the pair.
    /// @param owner address that will owned the private vault.
    /// @param module address of the default module.
    /// @param privateVault address of the deployed meta vault.
    event LogPrivateVaultCreation(
        address indexed creator,
        bytes32 salt,
        address token0,
        address token1,
        address owner,
        address module,
        address privateVault
    );

    /// @notice event emitted when whitelisting an array of public vault
    /// deployers.
    /// @param deployers list of deployers added to the whitelist.
    event LogWhitelistDeployers(address[] deployers);

    /// @notice event emitted when blacklisting an array of public vault
    /// deployers.
    /// @param deployers list of deployers removed from the whitelist.
    event LogBlacklistDeployers(address[] deployers);

    /// @notice event emitted when owner set a new manager.
    /// @param oldManager address of the previous manager.
    /// @param newManager address of the new manager.
    event LogSetManager(address oldManager, address newManager);

    // #endregion events.

    // #region state changing functions.

    /// @notice function used to pause the factory.
    /// @dev only callable by owner.
    function pause() external;

    /// @notice function used to unpause the factory.
    /// @dev only callable by owner.
    function unpause() external;

    /// @notice function used to set a new manager.
    /// @param newManager_ address that will managed newly created vault.
    /// @dev only callable by owner.
    function setManager(address newManager_) external;

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
    ) external returns (address vault);

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
    ) external returns (address vault);

    /// @notice function used to grant the role to deploy to a list of addresses.
    /// @param deployers_ list of addresses that owner want to grant permission to deploy.
    function whitelistDeployer(address[] calldata deployers_)
        external;

    /// @notice function used to grant the role to deploy to a list of addresses.
    /// @param deployers_ list of addresses that owner want to grant permission to deploy.
    function blacklistDeployer(address[] calldata deployers_)
        external;

    // #endregion state changing functions.

    // #region view/pure functions.

    /// @notice get Arrakis Modular standard token name for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return name name of the arrakis modular token vault.
    function getTokenName(
        address token0_,
        address token1_
    ) external view returns (string memory);

    /// @notice get Arrakis Modular standard token symbol for two corresponding tokens.
    /// @param token0_ address of the first token.
    /// @param token1_ address of the second token.
    /// @return symbol symbol of the arrakis modular token vault.
    function getTokenSymbol(
        address token0_,
        address token1_
    ) external view returns (string memory);

    /// @notice get a list of public vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function publicVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory);

    /// @notice numOfPublicVaults counts the total number of token vaults in existence
    /// @return result total number of vaults deployed
    function numOfPublicVaults()
        external
        view
        returns (uint256 result);

    /// @notice isPublicVault check if the inputed vault is a public vault.
    /// @param vault_ address of the address to check.
    /// @return isPublicVault true if the inputed vault is public or otherwise false.
    function isPublicVault(address vault_)
        external
        view
        returns (bool);

    /// @notice get a list of private vaults created by this factory
    /// @param startIndex_ start index
    /// @param endIndex_ end index
    /// @return vaults list of all created vaults.
    function privateVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory);

    /// @notice numOfPrivateVaults counts the total number of private vaults in existence
    /// @return result total number of vaults deployed
    function numOfPrivateVaults()
        external
        view
        returns (uint256 result);

    /// @notice isPrivateVault check if the inputed vault is a private vault.
    /// @param vault_ address of the address to check.
    /// @return isPublicVault true if the inputed vault is private or otherwise false.
    function isPrivateVault(address vault_)
        external
        view
        returns (bool);

    /// @notice function used to get the manager of newly deployed vault.
    /// @return manager address that will manager vault that will be
    /// created.
    function manager() external view returns (address);

    /// @notice function used to get a list of address that can deploy public vault.
    function deployers() external view returns (address[] memory);

    /// @notice function used to get public module registry.
    function moduleRegistryPublic() external view returns (address);

    /// @notice function used to get private module registry.
    function moduleRegistryPrivate()
        external
        view
        returns (address);

    // #endregion view/pure functions.
}
