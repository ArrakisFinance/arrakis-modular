// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SetupParams} from "../structs/SManager.sol";

interface ISelfPay {
    // #region errors.

    error AddressZero();
    error CantBeSelfPay();
    error VaultNFTNotTransferedOrApproved();
    error SameExecutor();
    error EmptyCallData();
    error CallFailed();
    error OnlyExecutor();

    // #endregion errors.

    // #region events.

    event LogSetExecutor(address oldExecutor, address newExecutor);
    event LogSetRouter(address oldRouter, address newRouter);
    event LogOwnerWithdraw(
        uint256 proportion, uint256 amount0, uint256 amount1
    );
    event LogOwnerWhitelistDepositors(address[] depositors);
    event LogOwnerBlacklistDepositors(address[] depositors);
    event LogOwnerWhitelistModules(
        address[] beacons, bytes[] payloads
    );
    event LogOwnerBlacklistModules(address[] modules);
    event LogOwnerCallNFT(bytes payload);
    event LogOwnerUpdateVaultInfo(SetupParams params);

    // #endregion events.

    // #region external functions.

    /// @notice function to initialize selfPay contract.
    function initialize() external;

    /// @notice function to withdraw token0 and token1 from the metaVault.
    /// @param proportion_ percentage of share to remove.
    /// @param receiver_ address that will receive withdrawn token0 and token1.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function to whitelist depositors of vault.
    /// @param depositors_ array of depositors to whitelist.
    function whitelistDepositors(address[] memory depositors_)
        external;

    /// @notice function to blacklist depositors of vault.
    /// @param depositors_ array of depositors to remove from whitelist.
    function blacklistDepositors(address[] memory depositors_)
        external;

    /// @notice function to whitelist modules on vault.
    /// @param beacons_ array of modules beacons to whitelist.
    /// @param payloads_ array of call data to initialize modules.
    function whitelistModules(
        address[] memory beacons_,
        bytes[] memory payloads_
    ) external;

    /// @notice function to blacklist whitelisted modules of vault.
    /// @param beacons_ array of modules beacons to blacklist.
    function blacklistModules(address[] memory beacons_) external;

    /// @notice function to set the new executor that will
    /// call rebalance function.
    /// @param executor_ address of the new executor.
    function setExecutor(address executor_) external;

    /// @notice function to call palmNFT.
    /// @param payload_ call data to palmNFT with.
    function callNFT(bytes memory payload_) external;

    /// @notice function to update management on chain config.
    /// @param params_ setupParams struct containing the new config.
    function updateVaultInfo(SetupParams memory params_) external;

    /// @notice function to do rebalance on vault through manager.
    /// @param payloads_ array of call data to use on active module
    /// of vault.
    function rebalance(bytes[] memory payloads_) external;

    // #endregion external functions.

    // #region external view functions.

    /// @notice function that return the seltPay's underlying vault.
    /// @return vault address of the underlying vault.
    function vault() external returns (address);

    /// @notice function that return the first token of the pair
    /// define on the vault.
    /// @return token0 address of the first token of the pair.
    function token0() external returns (address);

    /// @notice function that return the second token of the pair
    /// define on the vault.
    /// @return token1 address of the second token of the pair.
    function token1() external returns (address);

    /// @notice function that return the address of the manager.
    /// @return manager address of the contract managing the vault.
    function manager() external returns (address);

    /// @notice function that return palmNFT address, contract
    /// containing the information about ownership of private vault.
    /// @return nft address of palmNFT
    function nft() external returns (address);

    /// @notice function that return address of the executor of
    /// rebalance action.
    /// @return executor address of executor.
    function executor() external returns (address);

    // #endregion external view functions.
}