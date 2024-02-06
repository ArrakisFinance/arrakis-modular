// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SetupParams} from "../structs/SManager.sol";

interface IArrakisStandardManager {
    // #region errors.

    error EmptyNftRebalancersArray();
    error NotWhitelistedNftRebalancer(address nftRebalancer);
    error AlreadyWhitelistedNftRebalancer(address nftRebalancer);
    error VaultTypeNotSupported(bytes32 vaultType);
    error OnlyNftRebalancers(address caller);
    error EmptyString();
    error StratAlreadyWhitelisted();
    error StratNotWhitelisted();
    error OnlyPrivateVault();
    error OnlyERC20Vault();
    error OnlyVaultOwner(address caller, address vaultOwner);
    error AlreadyInManagement();
    error NotTheManager(address caller, address manager);
    error SlippageTooHigh();
    error MaxDeviationTooHigh();
    error CooldownPeriodSetToZero();
    error ValueDtBalanceInputed(uint256 value, uint256 balance);
    error OnlyOwner();
    error OnlyManagedVault();
    error DataIsUpdated();
    error SameStrat();
    error NotWhitelistedStrat();
    error NotNativeCoinSent();
    error NoEnoughBalance();
    error OverMaxSlippage();
    error NativeTokenDecimalsZero();
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
    error OnlyGuardian(address caller, address guardian);
    error FactoryAlreadySet();
    error OnlyFactory(address caller, address factory);
    error VaultNotDeployed();

    // #endregion errors.

    // #region events.

    event LogWhitelistNftRebalancers(address[] nftRebalancers);
    event LogBlacklistNftRebalancers(address[] nftRebalancers);
    event LogWhitelistStrategies(string[] strategies);
    event LogSetManagementParams(
        address indexed vault,
        address oracle,
        uint24 maxSlippagePIPS,
        uint24 maxDeviation,
        uint256 cooldownPeriod,
        address executor,
        address stratAnnouncer
    );
    event LogSetVaultData(address indexed vault, bytes datas);
    event LogSetVaultStrat(address indexed vault, string strat);
    event LogFundBalance(address indexed vault, uint256 balance);
    event LogWithdrawVaultBalance(
        address indexed vault,
        uint256 amount,
        address receiver,
        uint256 newBalance
    );
    event LogSetDefaultReceiver(address oldReceiver, address newReceiver);
    event LogSetReceiverByToken(address indexed token, address receiver);
    event LogWithdrawManagerBalance(
        address indexed receiver0,
        address indexed receiver1,
        uint256 amount0,
        uint256 amount1
    );
    event LogChangeManagerFee(address vault, uint256 newFeePIPS);
    event LogIncreaseManagerFeeSubmission(address vault, uint256 newFeePIPS);
    event LogRebalance(address indexed vault, bytes[] payloads);
    event LogSetModule(address indexed vault, address module, bytes[] payloads);
    event LogSetFactory(address vaultFactory);

    // #endregion events.

    // #region functions.

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

    /// @notice function used to set factory.
    /// @param factory_ address of the meta vault factory.
    function setFactory(address factory_) external;

    function initManagement(SetupParams calldata params_) external;

    function updateVaultInfo(SetupParams calldata params_) external;

    // #endregion functions.

    // #region view functions.

    function initializedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory);

    function numInitializedVaults() external view returns (uint256);

    /// @notice address of the pauser of manager.
    /// @return pauser address that can pause/unpause manager.
    function guardian() external view returns(address);

    /// @notice address of the vault factory.
    /// @return factory address that can deploy meta vault.
    function factory() external view returns(address);

    function isManaged(address vault_) external view returns(bool);

    // #endregion  view functions.
}
