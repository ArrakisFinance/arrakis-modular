// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// #region foundry.

import "forge-std/Test.sol";

// #endregion foundry.

import {IDopplerDeployer} from
    "../../../../src/interfaces/IDopplerDeployer.sol";
import {IDoppler} from "../../../../src/interfaces/IDoppler.sol";
import {DopplerData} from "../../../../src/structs/SDoppler.sol";

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

error NotImplemented();

contract DopplerMock is IDoppler, IHooks {

    address public token0;
    address public token1;

    uint256 public amount0;
    uint256 public amount1;

    function setTokens(
        address token0_,
        address token1_
    ) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0 = amount0_;
        amount1 = amount1_;
    }

    function migrate()
        external
        returns (uint256 amt0, uint256 amt1)
    {
        IERC20(token0).transfer(msg.sender, amount0);
        IERC20(token1).transfer(msg.sender, amount1);

        return (amount0, amount1);
    }
    function positions(
        bytes32 salt_
    )
        external
        view
        returns (
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint8 salt
        )
    {}

    function beforeInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        bytes calldata hookData
    ) external returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(
        address sender,
        PoolKey calldata key,
        uint160 sqrtPriceX96,
        int24 tick,
        bytes calldata hookData
    ) external returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterAddLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterRemoveLiquidity(
        address sender,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata params,
        BalanceDelta delta,
        BalanceDelta feesAccrued,
        bytes calldata hookData
    ) external returns (bytes4, BalanceDelta) {
        revert NotImplemented();
    }

    function beforeSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        bytes calldata hookData
    ) external returns (bytes4, BeforeSwapDelta, uint24) {
        revert NotImplemented();
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata hookData
    ) external returns (bytes4, int128) {
        revert NotImplemented();
    }

    function beforeDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }

    function afterDonate(
        address sender,
        PoolKey calldata key,
        uint256 amount0,
        uint256 amount1,
        bytes calldata hookData
    ) external returns (bytes4) {
        revert NotImplemented();
    }
}

contract DopplerDeployerMock is IDopplerDeployer, Test {
    function deployDoppler(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external returns (address) {
        DopplerMock doppler = DopplerMock(
            address(
                uint160(Hooks.AFTER_INITIALIZE_FLAG | Hooks.BEFORE_INITIALIZE_FLAG)
                )
        );

        DopplerMock impl = new DopplerMock();

        vm.etch(address(doppler), address(impl).code);

        return address(doppler);
    }

    function computeAddress(IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external view returns (address doppler) {
    }
}
