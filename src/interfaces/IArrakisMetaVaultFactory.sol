// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface IArrakisMetaVaultFactory {
    // #region errors.

    error AddressZero();

    /// @dev triggered when querying vaults on factory
    /// and start index is lower than end index.
    error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);

    /// @dev triggered when querying vaults on factory
    /// and end index of the query is bigger the biggest index of the vaults array.
    error EndIndexGtNbOfVaults(uint256 endIndex, uint256 numberOfVaults);

    // #endregion errors.

    // #region events.

    event LogPublicVaultCreation(
        address indexed creator,
        bytes32 salt,
        address token0,
        address token1,
        address owner,
        address module,
        address publicVault
    );
    event LogPrivateVaultCreation(
        address indexed creator,
        bytes32 salt,
        address token0,
        address token1,
        address owner,
        address module,
        address privateVault
    );

    // #endregion events.

    // #region state changing functions.

    /// @notice function used to deploy ERC20 token wrapped Arrakis
    /// Meta Vault.
    /// @param salt_ bytes32 used to get a deterministic all chains address.
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
        address module_
    ) external returns (address vault);

    /// @notice function used to deploy owned Arrakis
    /// Meta Vault.
    /// @param salt_ bytes32 needed to compute vault address deterministic way.
    /// @param token0_ address of the first token of the token pair.
    /// @param token1_ address of the second token of the token pair.
    /// @param owner_ address of the owner of the vault.
    /// @param module_ address of the initial module that will be used
    /// by Meta Vault.
    /// @return vault address of the newly created private Meta Vault.
    function deployPrivateVault(
        bytes32 salt_,
        address token0_,
        address token1_,
        address owner_,
        address module_
    ) external returns (address vault);

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
    function numOfPublicVaults() external view returns (uint256 result);

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
    function numOfPrivateVaults() external view returns (uint256 result);

    // #endregion view/pure functions.
}
