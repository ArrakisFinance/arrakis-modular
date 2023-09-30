// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisMetaLP} from "./interfaces/IArrakisMetaLP.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IERC20} from "./interfaces/IERC20.sol";
import {EnumerableSet} from "./libraries/EnumerableSet.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IManager} from "./interfaces/IManager.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";

contract ArrakisMetaLP is IArrakisMetaLP, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    error AddressZero();
    error AlreadyInSet();
    error NotInSet();
    error MalFormattedModule();
    error ModuleNotEmpty();
    error OnlyManager();
    error LengthMismatch();
    error CallFailed();
    error InvalidTarget();

    uint24 internal constant _PIPS = 1000000;

    uint256 internal immutable _init0;
    uint256 internal immutable _init1;

    address public immutable token0;
    address public immutable token1;

    address public manager;
    uint256 public managerFees0;
    uint256 public managerFees1;

    EnumerableSet.AddressSet internal _modules;
    EnumerableSet.AddressSet internal _swapRouters;

    constructor(address _token0, address _token1, address _owner, uint256 _init0_, uint256 _init1_) {
        token0 = _token0;
        token1 = _token1;
        _initializeOwner(_owner);
        _init0 = _init0_;
        _init1 = _init1_;
    }

    function deposit(uint256 proportion_) external onlyOwner {
        uint256 len = _modules.length();
        for (uint256 i = 0; i < len; i++) {
            IArrakisLPModule(_modules.at(i)).deposit(proportion_);
        }
    }

    function withdraw(uint24 proportion_, address receiver_) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        uint256 len = _modules.length();
        address _manager = manager;
        (uint256 fee0, uint256 fee1) = _manager != address(0) ? IManager(_manager).getFee(proportion_) : (0, 0);
        uint256 leftover0 = IERC20(token0).balanceOf(address(this));
        uint256 leftover1 = IERC20(token1).balanceOf(address(this));
        for (uint256 i = 0; i < len; i++) {
            (uint256 a0, uint256 a1) =
                IArrakisLPModule(_modules.at(i)).withdraw(proportion_);
            amount0 += a0;
            amount1 += a1;
        }
        amount0 += FullMath.mulDiv(leftover0, proportion_, _PIPS);
        amount1 += FullMath.mulDiv(leftover1, proportion_, _PIPS);
        amount0 -= fee0;
        amount1 -= fee1;
        if (fee0 > 0) IERC20(token0).transfer(_manager, fee0);
        if (fee1 > 0) IERC20(token1).transfer(_manager, fee1);
        if (amount0 > 0) IERC20(token0).transfer(receiver_, amount0);
        if (amount1 > 0) IERC20(token1).transfer(receiver_, amount1);
    }

    function rebalance(address[] calldata targets, bytes[] calldata payloads) external {
        if (msg.sender != manager) revert OnlyManager();
        
        uint256 len = targets.length;
        if (len != payloads.length) revert LengthMismatch();
        for (uint256 i = 0; i < len; i++) {
            address target = targets[i];
            if (!_modules.contains(target) && !_swapRouters.contains(target)) revert InvalidTarget();
            (bool success,) = target.call(payloads[i]);

            if (!success) revert CallFailed();
        }
    }

    function setManager(address newManager) external onlyOwner {
        manager = newManager;
    }

    function addSwapRouter(address newSwapRouter) external onlyOwner {
        if (newSwapRouter == address(0)) revert AddressZero();
        bool success = _swapRouters.add(newSwapRouter);

        if (!success) revert AlreadyInSet();

        IERC20(token0).approve(newSwapRouter, type(uint256).max);
        IERC20(token1).approve(newSwapRouter, type(uint256).max);
    }

    function removeSwapRouter(address oldSwapRouter) external onlyOwner {
        bool success = _swapRouters.remove(oldSwapRouter);

        if (!success) revert NotInSet();

        IERC20(token0).approve(oldSwapRouter, 0);
        IERC20(token1).approve(oldSwapRouter, 0);
    }

    function addModule(address newModule) external onlyOwner {
        if (newModule == address(0)) revert AddressZero();
        if (
            IArrakisLPModule(newModule).token0() != token0 ||
            IArrakisLPModule(newModule).token1() != token1 ||
            IOwnable(newModule).owner() != address(this)
        ) revert MalFormattedModule();

        bool success = _modules.add(newModule);

        if (!success) revert AlreadyInSet();

        IERC20(token0).approve(newModule, type(uint256).max);
        IERC20(token1).approve(newModule, type(uint256).max);
    }

    function removeModule(address oldModule) external onlyOwner {
        (uint256 amount0, uint256 amount1) = IArrakisLPModule(oldModule).totalUnderlying();
        if (amount0 != 0 || amount1 != 0) revert ModuleNotEmpty();

        bool success = _modules.remove(oldModule);

        if (!success) revert NotInSet();
        IERC20(token0).approve(oldModule, 0);
        IERC20(token1).approve(oldModule, 0);
    }

    function swapRouters() external view returns (address[] memory) {
        uint256 len = _swapRouters.length();
        address[] memory output = new address[](len);
        for (uint256 i; i < len; i++) {
            output[i] = _swapRouters.at(i);
        }

        return output;
    }

    function modules() external view returns (address[] memory) {
        uint256 len = _modules.length();
        address[] memory output = new address[](len);
        for (uint256 i; i < len; i++) {
            output[i] = _modules.at(i);
        }

        return output;
    }

    function getInits() external view returns (uint256, uint256) {
        uint256 out0 = _init0;
        uint256 out1 = _init1;
        uint256 len = _modules.length();
        for (uint256 i = 0; i < len; i++) {
            (uint256 a0, uint256 a1) = IArrakisLPModule(_modules.at(i)).getInits();
            out0 += a0;
            out1 += a1;
        }

        return (out0, out1);
    }

    function totalUnderlying() external view returns (uint256 amount0, uint256 amount1) {
        uint256 len = _modules.length();
        for (uint256 i = 0; i < len; i++) {
            (uint256 a0, uint256 a1) = IArrakisLPModule(_modules.at(i)).totalUnderlying();
            amount0 += a0;
            amount1 += a1;
        }

        amount0 += IERC20(token0).balanceOf(address(this));
        amount1 += IERC20(token1).balanceOf(address(this));
    }

    function totalUnderlyingAtPrice(uint256 priceX96) external view returns (uint256 amount0, uint256 amount1) {
        uint256 len = _modules.length();
        for (uint256 i = 0; i < len; i++) {
            (uint256 a0, uint256 a1) = IArrakisLPModule(_modules.at(i)).totalUnderlyingAtPrice(priceX96);
            amount0 += a0;
            amount1 += a1;
        }
    }
}