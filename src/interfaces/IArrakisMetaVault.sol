// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisLPModule} from "./IArrakisLPModule.sol";

/// @title IArrakisMetaVault
/// @notice IArrakisMetaVault is a vault that is able to invest dynamically deposited
/// tokens into protocols through his module.
interface IArrakisMetaVault {
    // #region errors.

    error AddressZero();
    error OnlyManager(address caller, address manager);
    error OnlyModule(address caller, address module);
    error ProportionGtPIPS(uint256 proportion);
    error ManagerFeePIPSTooHigh(uint24 managerFeePIPS);
    error CallFailed();
    error SameModule();
    error ModuleNotEmpty(uint256 amount0, uint256 amount1);
    error AlreadyWhitelisted(address module);
    error NotWhitelistedModule(address module);
    error ActiveModule();

    // #endregion errors.

    // #region events.

    event LogDeposit(uint256 proportion, uint256 amount0, uint256 amount1);
    event LogWithdraw(uint256 proportion, uint256 amount0, uint256 amount1);
    event LogRebalance(bytes[] payloads);
    event LogModuleCallback(address module, uint256 amount0, uint256 amount1);
    event LogWithdrawManagerBalance(uint256 amount0, uint256 amount1);
    event LogSetManager(address oldManager, address newManager);
    event LogSetModule(address module, bytes[] payloads_);
    event LogWhiteListedModules(address[] modules_);
    event LogBlackListedModules(address[] modules_);

    /// @dev storing manager fee on the contract will make it possible to
    /// change fee pips without retroactively applying new feePIPS to old
    /// fee earned.
    event LogSetManagerFeePIPS(
        uint24 oldManagerFeePIPS,
        uint24 newManagerFeePIPS
    );

    // #endregion events.

    /// @notice function used by manager to change the strategy
    /// @param payloads_ datas to use when calling module to rebalance the position.
    function rebalance(bytes[] calldata payloads_) external;

    /// @notice function used by module to get tokens
    function moduleCallback(uint256 amount0, uint256 amount1) external;

    /// @notice function used by manager to withdraw fees
    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used by owner to set the Manager
    /// responsible to rebalance the position.
    /// @param newManager_ address of the new manager.
    function setManager(address newManager_) external;

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
    function whitelistedModules()
        external
        view
        returns (address[] memory modules);

    /// @notice function used by manager to set the cut he will
    /// take from APY generated from the position managed.
    /// @dev value should be lower than 1 PIPS = 100_000
    /// @param managerFeePIP_ the percentage of cut the manager will take.
    function setManagerFeePIPS(uint24 managerFeePIP_) external;

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96 price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160 priceX96
    ) external view returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits() external view returns (uint256 init0, uint256 init1);

    /// @notice function used to get the address of token0.
    function token0() external view returns (address);

    /// @notice function used to get the address of token1.
    function token1() external view returns (address);

    /// @notice function used to get manager address.
    function manager() external view returns (address);

    /// @notice function used to get manager Fees in PIPS.
    function managerFeePIPS() external view returns (uint24);

    /// @notice function used to get manager balance in token0
    /// that can be withdrawn by manager.
    function managerBalance0() external view returns (uint256);

    /// @notice function used to get manager balance in token1
    /// that can be withdrawn by manager.
    function managerBalance1() external view returns (uint256);

    /// @notice function used to get module used to
    /// open/close/manager a position.
    function module() external view returns (IArrakisLPModule);
}
