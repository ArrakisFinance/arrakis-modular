// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IManager {
    // #region errors.

    error AddressZero();
    error NotWhitelistedVault(address vault);
    error AlreadyWhitelistedVault(address vault);
    error EmptyVaultArray();
    error CallFailed(bytes payload);
    error NotSameLengthArray(
        uint256 vaultsArrayLength,
        uint256 feePIPSArrayLength
    );

    // #endregion errors.

    // #region events.

    event LogSetDefaultReceiver(address oldReceiver, address newReceiver);
    event LogSetReceiverByToken(address indexed token, address receiver);
    event LogWithdrawManagerBalance(
        address indexed receiver0,
        address indexed receiver1,
        uint256 amount0,
        uint256 amount1
    );
    event LogWhitelistVault(address[] vaults);
    event LogBlacklistVault(address[] vaults);
    event LogRebalance(bytes[] payloads);
    event LogSetModule(address indexed vault, address module, bytes[] payloads);
    event LogSetManagerFeePIPS(address[] vaults, uint256[] feePIPS);

    // #endregion events.

    /// @notice function used by manager to get his balance of fees earned
    /// on a vault.
    /// @param vault_ from which fees will be collected.
    /// @return amount0 amount of token0 sent to receiver_
    /// @return amount1 amount of token1 sent to receiver_
    function withdrawManagerBalance(
        address vault_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used to add vault under management.
    /// @param vaults_ list of vault address to add.
    function whitelistVaults(address[] calldata vaults_) external;

    /// @notice function used to remove vault under management.
    /// @param vaults_ list of vault address to remove.
    function blacklistVaults(address[] calldata vaults_) external;

    /// @notice function used to manage vault's strategy.
    /// @param vault_ address of the vault that need a rebalance.
    /// @param payloads_ call data to do specific action of vault side.
    function rebalance(address vault_, bytes[] calldata payloads_) external;

    /// @notice function used to set a new module (strategy) for the vault.
    /// @param vault_ address of the vault the manager want to change module.
    /// @param module_ address of the new module.
    /// @param payloads_ call data to initialize position on the new module.
    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external;

    /// @notice function used to set fee taken by manager.
    /// @param vaults_ set of vault we want to update fees.
    /// @param feesPIPS_ array of fees to set on vaults.
    function setManagerFeePIPS(
        address[] calldata vaults_,
        uint256[] calldata feesPIPS_
    ) external;

    /// @notice function used to set the default receiver that
    /// will receive fund when a token don't have a specific receiver addr.
    /// @param newDefaultReceiver_ address that will receive tokens.
    function setDefaultReceiver(address newDefaultReceiver_) external;

    /// @notice function used to set the receiver that will receive a
    /// specific token.
    /// @param vault_ whitelisted metaVault.
    /// @param isSetReceiverToken0_ boolean defining if we should set receiver
    /// token0 or token1 of metaVault inputed.
    /// @param receiver_ address of the receiver of this specific token.
    function setReceiverByToken(
        address vault_,
        bool isSetReceiverToken0_,
        address receiver_
    ) external;

    /// @notice function used to get the list of vault under management.
    /// @return vaults set of vault under management.
    function whitelistedVaults()
        external
        view
        returns (address[] memory vaults);
}
