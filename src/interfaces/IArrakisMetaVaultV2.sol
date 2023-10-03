// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IArrakisMetaVaultV2 {
    // #region events.

    event LogSetModule(address module, bytes[] payloads_);
    event LogWhiteListedModules(address[] modules_);
    event LogBlackListedModules(address[] modules_);

    // #endregion events.

    /// @notice function used to set module
    /// @param module_ address of the new module
    /// @param payloads_ datas to initialize/rebalance on the new module
    function setModule(address module_, bytes[] calldata payloads_) external;

    /// @notice function used to whitelist modules that can used by manager.
    /// @param modules_ array of module addresses to be whitelisted.
    function whitelistModules(address[] calldata modules_) external;

    /// @notice function used to blacklist modules that can used by manager.
    /// @param modules_ array of module addresses to be blacklisted.
    function blacklistModules(address[] calldata modules_) external;

    /// @notice function used to get the list of modules whitelisted.
    /// @return modules whitelisted modules addresses.
    function whitelistedModules() external view returns(address[] memory modules);
}

