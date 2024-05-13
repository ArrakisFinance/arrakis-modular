// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IModuleRegistry} from "../interfaces/IModuleRegistry.sol";
import {BASE} from "../constants/CArrakis.sol";

import {ReentrancyGuard} from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {Initializable} from
    "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract ArrakisMetaVault is
    IArrakisMetaVault,
    ReentrancyGuard,
    Initializable
{
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region immutable properties.

    address public immutable moduleRegistry;
    address public immutable token0;
    address public immutable token1;

    // #endregion immutable properties.

    // #region public properties.

    IArrakisLPModule public module;
    address public manager;

    // #endregion public properties.

    EnumerableSet.AddressSet internal _whitelistedModules;

    // #region modifier.

    modifier onlyOwnerCustom() {
        _onlyOwnerCheck();
        _;
    }

    modifier onlyManager() {
        if (msg.sender != manager) {
            revert OnlyManager(msg.sender, manager);
        }
        _;
    }

    // #endregion modifier.

    constructor(
        address moduleRegistry_,
        address manager_,
        address token0_,
        address token1_
    ) {
        // #region checks.

        if (moduleRegistry_ == address(0)) {
            revert AddressZero("Module Registry");
        }
        if (manager_ == address(0)) revert AddressZero("Manager");
        if (token0_ == address(0)) revert AddressZero("Token 0");
        if (token1_ == address(0)) revert AddressZero("Token 1");
        if (token0_ > token1_) revert Token0GtToken1();
        if (token0_ == token1_) revert Token0EqToken1();

        // #endregion checks.

        moduleRegistry = moduleRegistry_;
        manager = manager_;
        token0 = token0_;
        token1 = token1_;

        emit LogSetManager(manager_);
    }

    function initialize(address module_) external initializer {
        if (module_ == address(0)) revert AddressZero("Module");

        _whitelistedModules.add(module_);
        module = IArrakisLPModule(module_);

        emit LogSetFirstModule(module_);
        emit LogWhitelistedModule(module_);
    }

    /// @notice function used to set module
    /// @param module_ address of the new module
    /// @param payloads_ datas to initialize/rebalance on the new module
    function setModule(
        address module_,
        bytes[] calldata payloads_
    ) external onlyManager nonReentrant {
        // store in memory to save gas.
        IArrakisLPModule _module = module;

        if (address(_module) == module_) revert SameModule();
        if (!_whitelistedModules.contains(module_)) {
            revert NotWhitelistedModule(module_);
        }

        module = IArrakisLPModule(module_);

        // #region withdraw manager fees balances.

        _withdrawManagerBalance(_module);

        // #endregion withdraw manager fees balances.

        // #region move tokens to the new module.

        /// @dev we transfer here all tokens to the new module.
        _module.withdraw(module_, BASE);

        // #endregion move tokens to the new module.

        // #region check if the module is empty.

        // #endregion check if the module is empty.

        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success,) = module_.call(payloads_[i]);
            if (!success) revert CallFailed();
        }
        emit LogSetModule(module_, payloads_);
    }

    /// @notice function used to whitelist modules that can used by manager.
    /// @param beacons_ array of beacons addresses to use for modules creation.
    /// @param data_ array of payload to use for modules creation.
    function whitelistModules(
        address[] calldata beacons_,
        bytes[] calldata data_
    ) external onlyOwnerCustom {
        uint256 len = beacons_.length;
        if (len != data_.length) revert ArrayNotSameLength();

        address[] memory modules = new address[](len);
        for (uint256 i; i < len; i++) {
            address _module = IModuleRegistry(moduleRegistry)
                .createModule(address(this), beacons_[i], data_[i]);

            modules[i] = _module;

            _whitelistedModules.add(_module);
        }

        emit LogWhiteListedModules(modules);
    }

    /// @notice function used to blacklist modules that can used by manager.
    /// @param modules_ array of module addresses to be blacklisted.
    function blacklistModules(address[] calldata modules_)
        external
        onlyOwnerCustom
    {
        uint256 len = modules_.length;
        for (uint256 i; i < len; i++) {
            address _module = modules_[i];
            if (!_whitelistedModules.contains(_module)) {
                revert NotWhitelistedModule(_module);
            }
            if (address(module) == _module) revert ActiveModule();
            _whitelistedModules.remove(_module);
        }

        emit LogBlackListedModules(modules_);
    }

    /// @notice function used to get the list of modules whitelisted.
    /// @return modules whitelisted modules addresses.
    function whitelistedModules()
        external
        view
        returns (address[] memory modules)
    {
        return _whitelistedModules.values();
    }

    // #region view functions.

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {
        return module.getInits();
    }

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return module.totalUnderlying();
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(uint160 priceX96_)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return module.totalUnderlyingAtPrice(priceX96_);
    }

    // #endregion view functions.

    // #region internal functions.

    function _withdraw(
        address receiver_,
        uint256 proportion_
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module.withdraw(receiver_, proportion_);
    }

    function _withdrawManagerBalance(IArrakisLPModule module_)
        internal
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = module_.withdrawManagerBalance();

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    function _onlyOwnerCheck() internal view virtual;

    // #endregion internal functions.
}
