// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {PIPS} from "./constants/CArrakis.sol";

contract ArrakisMetaVault is IArrakisMetaVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region immutable properties.

    address public immutable token0;
    address public immutable token1;

    // #endregion immutable properties.

    // #region public properties.

    IArrakisLPModule public module;
    address public manager;

    // #endregion public properties.

    EnumerableSet.AddressSet internal _whitelistedModules;

    // #region modifier.

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager(msg.sender, manager);
        _;
    }

    // #endregion modifier.

    constructor(
        address token0_,
        address token1_,
        address owner_,
        address module_
    ) {
        // #region checks.

        if (token0_ == address(0)) revert AddressZero("Token 0");
        if (token1_ == address(0)) revert AddressZero("Token 1");
        if (token0_ > token1_) revert Token0GtToken1();
        if (token0_ == token1_) revert Token0EqToken1();
        if (owner_ == address(0)) revert AddressZero("Owner");
        if (module_ == address(0)) revert AddressZero("Module");

        // #endregion checks.

        token0 = token0_;
        token1 = token1_;
        _initializeOwner(owner_);
        _whitelistedModules.add(module_);
        module = IArrakisLPModule(module_);

        emit LogSetFirstModule(module_);
        emit LogWhitelistedModule(module_);
    }

    function setManager(address newManager_) external onlyOwner nonReentrant {
        address _manager = manager;
        if (newManager_ == address(0))
            revert AddressZero("New Manager");
        if (newManager_ == _manager)
            revert SameManager();
        if (_manager != address(0)) _withdrawManagerBalance(module);
        manager = newManager_;

        emit LogSetManager(_manager, newManager_);
    }

    function setModule(
        address module_,
        bytes[] calldata payloads_
    ) external onlyManager nonReentrant {
        // store in memory to save gas.
        IArrakisLPModule _module = module;

        if (address(_module) == module_) revert SameModule();
        if (!_whitelistedModules.contains(module_))
            revert NotWhitelistedModule(module_);

        module = IArrakisLPModule(module_);

        // #region withdraw manager fees balances.

        _withdrawManagerBalance(_module);

        // #endregion withdraw manager fees balances.

        // #region move tokens to the new module.

        /// @dev we transfer here all tokens to the new module.
        _module.withdraw(module_, PIPS);

        // #endregion move tokens to the new module.

        // #region check if the module is empty.
        /// @dev module implementation should take into account
        /// that wrongly implemented module can freeze the modularity
        /// of ArrakisMetaVault if withdrawManagerBalance + withdraw 100%
        /// don't transfer every tokens (0/1) from module.
        (uint256 amount0, uint256 amount1) = _module.totalUnderlying();
        if (amount0 != 0 || amount1 != 0)
            revert ModuleNotEmpty(amount0, amount1);

        // #endregion check if the module is empty.

        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, ) = module_.call(payloads_[i]);
            if (!success) revert CallFailed();
        }
        emit LogSetModule(module_, payloads_);
    }

    function whitelistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for (uint256 i; i < len; i++) {
            address _module = modules_[i];
            if (_module == address(0))
                revert AddressZero("Module");
            if (_whitelistedModules.contains(_module))
                revert AlreadyWhitelisted(_module);
            _whitelistedModules.add(_module);
        }

        emit LogWhiteListedModules(modules_);
    }

    function blacklistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for (uint256 i; i < len; i++) {
            address _module = modules_[i];
            if (!_whitelistedModules.contains(_module))
                revert NotWhitelistedModule(_module);
            if (address(module) == _module) revert ActiveModule();
            _whitelistedModules.remove(_module);
        }

        emit LogBlackListedModules(modules_);
    }

    function whitelistedModules()
        external
        view
        returns (address[] memory modules)
    {
        return _whitelistedModules.values();
    }

    // #region view functions.

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return module.getInits();
    }

    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return module.totalUnderlying();
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return module.totalUnderlyingAtPrice(priceX96_);
    }

    // #endregion view functions.

    // #region internal functions.

    function _deposit(
        uint256 proportion_
    ) internal nonReentrant returns (uint256 amount0, uint256 amount1) {
        /// @dev msg.sender should be the tokens provider
        (uint256 amount0, uint256 amount1) = module.deposit{value: msg.value}(
            msg.sender,
            proportion_
        );
        emit LogDeposit(proportion_, amount0, amount1);
    }

    function _withdraw(
        address receiver_,
        uint256 proportion_
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module.withdraw(receiver_, proportion_);

        emit LogWithdraw(proportion_, amount0, amount1);
    }

    function _withdrawManagerBalance(
        IArrakisLPModule module_
    ) internal returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module_.withdrawManagerBalance();

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    // #endregion internal functions.
}
