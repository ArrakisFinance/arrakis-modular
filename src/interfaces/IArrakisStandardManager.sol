// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SetupParams} from "../structs/SManager.sol";

interface IArrakisStandardManager {
    // #region errors.

    error OnlyVaultOwner(address caller, address vaultOwner);
    error AlreadyInManagement();
    error NotTheManager(address caller, address manager);
    error SlippageTooHigh();
    error CooldownPeriodSetToZero();
    error OnlyOwner();
    error OnlyManagedVault();
    error OverMaxSlippage();
    error NotFeeDecrease();
    error AlreadyPendingIncrease();
    error NotFeeIncrease();
    error TimeNotPassed();
    error NoPendingIncrease();
    error NotExecutor();
    error NotStratAnnouncer();
    error AddressZero();
    error NotWhitelistedVault(address vault);
    error AlreadyWhitelistedVault(address vault);
    error EmptyVaultsArray();
    error CallFailed(bytes payload);
    error StartIndexLtEndIndex(uint256 startIndex, uint256 endIndex);
    error EndIndexGtNbOfVaults(uint256 endIndex, uint256 numberOfVaults);

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
    event LogRebalance(address indexed vault, bytes[] payloads);
    event LogSetModule(address indexed vault, address module, bytes[] payloads);

    event LogSetManagementParams(
        address indexed vault,
        uint256 cooldownPeriod,
        address oracle,
        address executor,
        address stratAnnouncer,
        uint24 maxSlippagePIPS
    );

    event LogStrategyData(
        address indexed vault,
        bytes data
    );

    event LogChangeManagerFee(address indexed vault, uint24 managerFeePIPS);

    // #endregion events.

    /// @notice function used by manager to get his balance of fees earned
    /// on a vault.
    /// @param vault_ from which fees will be collected.
    /// @return amount0 amount of token0 sent to receiver_
    /// @return amount1 amount of token1 sent to receiver_
    function withdrawManagerBalance(
        address vault_
    ) external returns (uint256 amount0, uint256 amount1);

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

    function initManagement(SetupParams calldata params_) external;

    function updateVaultInfo(SetupParams calldata params_) external;

    // #region view functions.

    function initializedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    )
        external
        view
        returns (address[] memory);
    
    function numInitializedVaults() external view returns (uint256);

    // #endregion view functions.
}
