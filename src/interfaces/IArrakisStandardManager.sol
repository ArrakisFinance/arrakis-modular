// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {SetupParams} from "../structs/SManager.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

interface IArrakisStandardManager {
    // #region errors.

    error EmptyNftRebalancersArray();
    error NotWhitelistedNftRebalancer(address nftRebalancer);
    error AlreadyWhitelistedNftRebalancer(address nftRebalancer);
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
    error EndIndexGtNbOfVaults(
        uint256 endIndex, uint256 numberOfVaults
    );
    error OnlyGuardian(address caller, address guardian);
    error OnlyFactory(address caller, address factory);
    error VaultNotDeployed();
    error SetManagerFeeCallNotAllowed();
    error OnlyStratAnnouncer();

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
    event LogSetDefaultReceiver(
        address oldReceiver, address newReceiver
    );
    event LogSetReceiverByToken(
        address indexed token, address receiver
    );
    event LogWithdrawManagerBalance(
        address indexed receiver0,
        address indexed receiver1,
        uint256 amount0,
        uint256 amount1
    );
    event LogChangeManagerFee(address vault, uint256 newFeePIPS);
    event LogIncreaseManagerFeeSubmission(
        address vault, uint256 newFeePIPS
    );
    event LogRebalance(address indexed vault, bytes[] payloads);
    event LogSetModule(
        address indexed vault, address module, bytes[] payloads
    );
    event LogSetFactory(address vaultFactory);
    event LogStrategyAnnouncement(address vault, string strategy);

    // #endregion events.

    // #region functions.

    /// @notice function used to initialize standard manager proxy.
    /// @param owner_ address of the owner of standard manager.
    /// @param defaultReceiver_ address of the receiver of tokens (by default).
    /// @param factory_ ArrakisMetaVaultFactory contract address.
    function initialize(
        address owner_,
        address defaultReceiver_,
        address factory_
    ) external;

    /// @notice function used to pause the manager.
    /// @dev only callable by guardian
    function pause() external;

    /// @notice function used to unpause the manager.
    /// @dev only callable by guardian
    function unpause() external;

    /// @notice function used to set the default receiver of tokens earned.
    /// @param newDefaultReceiver_ address of the new default receiver of tokens.
    function setDefaultReceiver(address newDefaultReceiver_)
        external;

    /// @notice function used to set receiver of a specific token.
    /// @param vault_ address of the meta vault that contain the specific token.
    /// @param isSetReceiverToken0_ boolean if true means that receiver is for token0
    /// if not it's for token1.
    /// @param receiver_ address of the receiver of this specific token.
    function setReceiverByToken(
        address vault_,
        bool isSetReceiverToken0_,
        address receiver_
    ) external;

    /// @notice function used to decrease the fees taken by manager for a specific managed vault.
    /// @param vault_ address of the vault.
    /// @param newFeePIPS_ fees in pips to set on the specific vault.
    function decreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external;

    /// @notice function used to finalize a time lock fees increase on a vault.
    /// @param vault_ address of the vault where the fees increase will be
    /// applied.
    function finalizeIncreaseManagerFeePIPS(address vault_)
        external;

    /// @notice function used to submit a fees increase in a managed vault.
    /// @param vault_ address of the vault where fees will be increase after timeLock.
    /// @param newFeePIPS_ fees in pips to set on the specific managed vault.
    function submitIncreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external;

    /// @notice function used by manager to get his balance of fees earned
    /// on a vault.
    /// @param vault_ from which fees will be collected.
    /// @return amount0 amount of token0 sent to receiver_
    /// @return amount1 amount of token1 sent to receiver_
    function withdrawManagerBalance(address vault_)
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to manage vault's strategy.
    /// @param vault_ address of the vault that need a rebalance.
    /// @param payloads_ call data to do specific action of vault side.
    function rebalance(
        address vault_,
        bytes[] calldata payloads_
    ) external;

    /// @notice function used to set a new module (strategy) for the vault.
    /// @param vault_ address of the vault the manager want to change module.
    /// @param module_ address of the new module.
    /// @param payloads_ call data to initialize position on the new module.
    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external;

    /// @notice function used to init management of a meta vault.
    /// @param params_ struct containing all the data for initialize the vault.
    function initManagement(SetupParams calldata params_) external;

    /// @notice function used to update meta vault management informations.
    /// @param params_ struct containing all the data for updating the vault.
    function updateVaultInfo(SetupParams calldata params_) external;

    /// @notice function used to announce the strategy that the vault will follow.
    /// @param vault_ address of arrakis meta vault that will follow the strategy.
    /// @param strategy_ string containing the strategy name that will be used.
    function announceStrategy(
        address vault_,
        string memory strategy_
    ) external;

    // #endregion functions.

    // #region view functions.

    /// @notice function used to get a list of managed vaults.
    /// @param startIndex_ starting index from which the caller want to read the array of managed vaults.
    /// @param endIndex_ ending index until which the caller want to read the array of managed vaults.
    function initializedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view returns (address[] memory);

    /// @notice function used to get the number of vault under management.
    /// @param numberOfVaults number of under management vault.
    function numInitializedVaults()
        external
        view
        returns (uint256 numberOfVaults);

    /// @notice address of the pauser of manager.
    /// @return pauser address that can pause/unpause manager.
    function guardian() external view returns (address);

    /// @notice address of the vault factory.
    /// @return factory address that can deploy meta vault.
    function factory() external view returns (address);

    /// @notice function used to get the default fee applied on manager vault.
    /// @return defaultFeePIPS amount of default fees.
    function defaultFeePIPS() external view returns (uint256);

    /// @notice function used to get the native token/coin of the chain.
    /// @return nativeToken address of the native token/coin of the chain.
    function nativeToken() external view returns (address);

    /// @notice function used to get the native token/coin decimals precision.
    /// @return nativeTokenDecimals decimals precision of the native coin.
    function nativeTokenDecimals() external view returns (uint8);

    /// @notice function used to get the default receiver of tokens earned in managed vault.
    /// @return defaultReceiver address of the default receiver.
    function defaultReceiver() external view returns (address);

    /// @notice function used to get the receiver of a specific token.
    /// @param token_ address of the ERC20 token that we want the receiver of
    /// @return receiver address of the receiver of 'token_'
    function receiversByToken(address token_)
        external
        view
        returns (address receiver);

    /// @notice function used to get vault management config.
    /// @param vault_ address of the metaVault.
    /// @return lastRebalance timestamp when the last rebalance happen.
    /// @return cooldownPeriod minimum duration between two rebalance.
    /// @return oracle oracle used to check against price manipulation.
    /// @return maxDeviation maximum deviation from oracle price allowed.
    /// @return executor address that can trigger a rebalance.
    /// @return stratAnnouncer address that will announce a strategy to follow.
    /// @return maxSlippagePIPS maximum slippage authorized.
    /// @return managerFeePIPS fees that manager take.
    function vaultInfo(address vault_)
        external
        view
        returns (
            uint256 lastRebalance,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            address executor,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
            uint24 managerFeePIPS
        );

    // #endregion  view functions.
}
