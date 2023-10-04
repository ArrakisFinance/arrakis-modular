// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";
import {PIPS} from "./constants/CArrakis.sol";

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

contract ArrakisMetaVault is IArrakisMetaVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    // #region internal immutable.

    uint256 internal immutable _init0;
    uint256 internal immutable _init1;

    // #endregion internal immutable.

    // #region immutable properties.

    address public immutable token0;
    address public immutable token1;

    // #endregion immutable properties.

    // #region public manager properties.

    address public manager;
    uint256 public managerBalance0;
    uint256 public managerBalance1;
    uint24 public managerFeePIPS;

    // #endregion public manager properties.

    // #region public properties.

    IArrakisLPModule public module;

    // #endregion public properties.

    EnumerableSet.AddressSet internal _whitelistedModules;

    // #region transient storage.

    address internal _tokenSender;

    // #endregion transient storage.

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
        uint256 init0_,
        uint256 init1_,
        address module_
    ) {
        token0 = token0_;
        token1 = token1_;
        _initializeOwner(owner_);
        _init0 = init0_;
        _init1 = init1_;
        module =IArrakisLPModule(module_);
    }

    function rebalance(bytes[] calldata payloads_) external onlyManager {
        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, ) = address(module).call(payloads_[i]);

            if (!success) revert CallFailed();
        }

        emit LogRebalance(payloads_);
    }

    function moduleCallback(uint256 amount0_, uint256 amount1_) external {
        if (msg.sender != address(module))
            revert OnlyModule(msg.sender, address(module));

        if (amount0_ > 0)
            IERC20(token0).safeTransferFrom(
                _tokenSender,
                address(module),
                amount0_
            );

        if (amount1_ > 0)
            IERC20(token1).safeTransferFrom(
                _tokenSender,
                address(module),
                amount1_
            );

        emit LogModuleCallback(address(module), amount0_, amount1_);
    }

    function setManager(address newManager) external onlyOwner {
        withdrawManagerBalance();

        emit LogSetManager(manager, manager = newManager);
    }

    function setManagerFeePIPS(uint24 newManagerFeePIPS) external onlyManager {
        emit LogSetManagerFeePIPS(managerFeePIPS, managerFeePIPS = newManagerFeePIPS);
    }

    function setModule(
        address module_,
        bytes[] calldata payloads_
    ) external onlyManager {
        if (address(module) == module_) revert SameModule();
        if (!_whitelistedModules.contains(module_))
            revert NotWhitelistedModule(module_);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();
        if (amount0 != 0 || amount1 != 0)
            revert ModuleNotEmpty(amount0, amount1);

        module = IArrakisLPModule(module_);

        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, ) = address(module).call(payloads_[i]);
            if (!success) revert CallFailed();
        }
        emit LogSetModule(module_, payloads_);
    }

    function whitelistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for(uint256 i; i<len; i++) {
            if(_whitelistedModules.contains(modules_[i]))
                revert NotWhitelistedModule(modules_[i]);
            _whitelistedModules.add(modules_[i]);
        }

        emit LogWhiteListedModules(modules_);
    }

    function blacklistModules(address[] calldata modules_) external onlyOwner {
        uint256 len = modules_.length;
        for(uint256 i; i<len; i++) {
            if(!_whitelistedModules.contains(modules_[i]))
                revert AlreadyWhitelisted(modules_[i]);
            if(address(module) == modules_[i])
                revert ActiveModule();
            _whitelistedModules.remove(modules_[i]);
        }

        emit LogBlackListedModules(modules_);
    }

    function whitelistedModules() external view returns(address[] memory modules) {
        return _whitelistedModules.values();
    }

    function withdrawManagerBalance()
        public
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = managerBalance0;
        amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) IERC20(token0).safeTransfer(manager, amount0);
        if (amount1 > 0) IERC20(token1).safeTransfer(manager, amount1);

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    // #region view functions.

    function getInits() external view returns (uint256 init0, uint256 init1) {
        (init0, init1) = module.getInits();
        init0 += _init0;
        init1 += _init1;
    }

    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = module.totalUnderlying();

        amount0 += IERC20(token0).balanceOf(address(this)) - managerBalance0;
        amount1 += IERC20(token1).balanceOf(address(this)) - managerBalance1;
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module.totalUnderlyingAtPrice(priceX96_);

        amount0 += IERC20(token0).balanceOf(address(this)) - managerBalance0;
        amount1 += IERC20(token1).balanceOf(address(this)) - managerBalance1;
    }

    // #endregion view functions.

    // #region internal functions.

    function _deposit(
        uint256 proportion_
    ) internal nonReentrant returns (uint256 amount0, uint256 amount1) {
        (uint256 total0, uint256 total1) = totalUnderlying();
        amount0 = FullMath.mulDiv(total0, proportion_,PIPS);
        amount1 = FullMath.mulDiv(total1, proportion_, PIPS);
        uint256 feeProportion = FullMath.mulDiv(proportion_, managerFeePIPS, PIPS);
        _tokenSender = msg.sender;
        (uint256 d0, uint256 d1) = module.deposit(proportion_-feeProportion);

        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount0-d0);
        IERC20(token0).safeTransferFrom(msg.sender, address(this), amount1-d1);

        managerBalance0 += FullMath.mulDiv(total0, feeProportion, PIPS);
        managerBalance1 += FullMath.mulDiv(total1, feeProportion, PIPS);

        emit LogDeposit(proportion_, amount0, amount1);
    }

    function _withdraw(
        uint256 proportion_
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (proportion_ > PIPS) revert ProportionGtPIPS(proportion_);
        uint256 leftover0 = IERC20(token0).balanceOf(address(this)) -
            managerBalance0;
        uint256 leftover1 = IERC20(token1).balanceOf(address(this)) -
            managerBalance1;

        (amount0, amount1) = module.withdraw(proportion_);

        amount0 += FullMath.mulDiv(leftover0, proportion_, PIPS);
        amount1 += FullMath.mulDiv(leftover1, proportion_, PIPS);

        emit LogWithdraw(proportion_, amount0, amount1);
    }

    // #endregion internal functions.
}
