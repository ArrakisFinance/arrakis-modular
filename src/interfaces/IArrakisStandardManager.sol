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
    error CoolDownPeriodSetToZero();
    error ValueDtBalanceInputed(uint256 value, uint256 balance);
    error OnlyOwner();
    error OnlyManagedVault();
    error DataIsUpdated();
    error SameStrat();
    error NotWhitelistedStrat();
    error NotNativeCoinSent();
    error NoEnoughBalance();
    error OverMaxSlippage();

    // #endregion errors.

    // #region events.

    event LogWhitelistNftRebalancers(address[] nftRebalancers);
    event LogBlacklistNftRebalancers(address[] nftRebalancers);
    event LogWhitelistStrategies(string[] strategies);
    event LogInitManagement(
        address indexed vault,
        uint256 balance,
        bytes datas,
        address oracle,
        uint24 maxSlippage,
        uint256 managerFeeBPS,
        uint256 coolDownPeriod,
        bytes32 strat
    );
    event LogSetVaultData(
        address indexed vault,
        bytes datas
    );
    event LogSetVaultStrat(
        address indexed vault,
        string strat
    );
    event LogFundBalance(
        address indexed vault,
        uint256 balance
    );
    event LogWithdrawVaultBalance(
        address indexed vault,
        uint256 amount,
        address receiver,
        uint256 newBalance
    );

    // #endregion events.

    // #region public functions.

    function whitelistStrategies(string[] calldata strategies_) external;

    function whitelistNftRebalancers(
        address[] calldata nftRebalancers_
    ) external;

    function blacklistNftRebalancers(
        address[] calldata nftRebalancers_
    ) external;

    function initManagement(SetupParams calldata params_) external payable;

    function setVaultData(address vault_, bytes calldata datas_) external;

    function setVaultStratByName(address vault_, string calldata strat_) external;

    function fundVaultBalance(address vault_) external payable;

    function withdrawVaultBalance(address vault_, uint256 amount_, address receiver_) external;

    // #endregion public functions.

    // #region public view functions.

    function whitelistedStrategies()
        external
        view
        returns (bytes32[] memory strats);

    /// @notice function used to get the list of nft rebalancers.
    /// @return nftRebalancers set of rebalancers for nft vault.
    function whitelistedNftRebalancers()
        external
        view
        returns (address[] memory nftRebalancers);

    // #endregion public view functions.
}
