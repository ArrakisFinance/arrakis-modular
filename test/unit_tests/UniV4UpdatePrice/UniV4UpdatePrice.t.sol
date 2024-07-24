// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region Uniswap Module.
import {UniV4UpdatePrice} from
    "../../../src/modules/UniV4UpdatePrice.sol";
import {IUniV4UpdatePrice} from
    "../../../src/interfaces/IUniV4UpdatePrice.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {PermissionHook} from "../../../src/hooks/PermissionHook.sol";
import {IUniV4StandardModule} from
    "../../../src/interfaces/IUniV4StandardModule.sol";
import {BASE} from "../../../src/constants/CArrakis.sol";
// #endregion Uniswap Module.

// #region openzeppelin.
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// #endregion openzeppelin.

// #region uniswap v4.
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {StateLibrary} from
    "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {TransientStateLibrary} from
    "@uniswap/v4-core/src/libraries/TransientStateLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {LiquidityAmounts} from
    "@uniswap/v4-periphery/contracts/libraries/LiquidityAmounts.sol";
import {
    PoolIdLibrary,
    PoolId
} from "@uniswap/v4-core/src/types/PoolId.sol";
// #endregion uniswap v4.

// #region mocks.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleMock} from "./mocks/OracleWrapperMock.sol";
import {SimpleHook} from "./mocks/SimpleHook.sol";
// #endregion mocks.

contract UniV4UpdatePriceTest is TestWrapper {
    using StateLibrary for IPoolManager;
    using TransientStateLibrary for IPoolManager;
    using PoolIdLibrary for PoolKey;

    // #region constants.

    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constants.

    PoolManager public poolManager;
    PoolKey public poolKey;
    uint160 public sqrtPriceX96;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;

    UniV4UpdatePrice public module;
    PermissionHook public hook;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        // #region meta vault creation.

        metaVault = address(new ArrakisMetaVaultMock(manager, owner));

        // #endregion meta vault creation.

        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.

        // #region do a poolManager deployment.

        poolManager = new PoolManager(0);

        // #endregion do a poolManager deployment.

        // #region create a uni v4 update price module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        module = new UniV4UpdatePrice(
            address(poolManager),
            metaVault,
            USDC,
            WETH,
            init0,
            init1,
            guardian,
            false
        );

        // #endregion create a uni v4 update price module.

        // #region create a permission hook.

        PermissionHook hook = PermissionHook(
            address(
                uint160(
                    Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                        | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
                )
            )
        );

        PermissionHook implementation =
            new PermissionHook(address(module));

        vm.etch(address(hook), address(implementation).code);

        // #endregion create a permission hook.

        // #region create a pool.

        Currency currency0 = Currency.wrap(USDC);
        Currency currency1 = Currency.wrap(WETH);

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 10_000,
            tickSpacing: 10,
            hooks: IHooks(address(hook))
        });

        sqrtPriceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;

        poolManager.unlock(abi.encode(2));

        // #endregion create a pool.

        vm.prank(IOwnable(address(metaVault)).owner());
        module.initializePoolKey(poolKey);
    }

    // #region uniswap v4 callback function.

    function unlockCallback(bytes calldata data)
        public
        returns (bytes memory)
    {
        uint256 typeOfLockAcquired = abi.decode(data, (uint256));

        // if (typeOfLockAcquired == 0) _lockAcquiredAddPosition();
        // if (typeOfLockAcquired == 1) {
        //     _lockAcquiredSwap();
        // }

        if (typeOfLockAcquired == 2) {
            poolManager.initialize(poolKey, sqrtPriceX96, "");
        }

        // if (typeOfLockAcquired == 3) {
        //     _lockAcquiredSwapBis();
        // }
    }

    // #endregion uniswap v4 callback function.

    // #region test getPositionKey.

    function testGetPositionKey() public {
        address owner =
            vm.addr(uint256(keccak256(abi.encode("Owner"))));
        int24 tickLower = TickMath.MIN_TICK / 2;
        int24 tickUpper = TickMath.MAX_TICK / 2;

        bytes32 salt = keccak256(abi.encode("Salt"));

        bytes32 positionKey = keccak256(
            abi.encodePacked(owner, tickLower, tickUpper, salt)
        );

        bytes32 currentPositionKey =
            module.getPositionKey(owner, tickLower, tickUpper, salt);

        assertEq(positionKey, currentPositionKey);
    }

    // #endregion test getPositionKey.

    // #region test movePrice.

    function testMovePrice() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        {
            address depositor =
                vm.addr(uint256(keccak256(abi.encode("Depositor"))));

            // #region deposit.

            deal(USDC, depositor, init0);
            deal(WETH, depositor, init1);

            vm.startPrank(depositor);
            IERC20Metadata(USDC).approve(address(module), init0);
            IERC20Metadata(WETH).approve(address(module), init1);
            vm.stopPrank();

            vm.prank(metaVault);
            module.deposit(depositor, BASE);
        }

        // #endregion deposit.

        // #region do rebalance.

        int24 tick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);

        int24 tickLower = (tick / 10) * 10 - (100 * 10);
        int24 tickUpper = (tick / 10) * 10 + (100 * 10);

        IUniV4StandardModule.Range memory range = IUniV4StandardModule
            .Range({tickLower: tickLower, tickUpper: tickUpper});

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0,
            init1
        );

        IUniV4StandardModule.LiquidityRange memory liquidityRange =
        IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        IUniV4StandardModule.LiquidityRange[] memory liquidityRanges =
            new IUniV4StandardModule.LiquidityRange[](1);

        liquidityRanges[0] = liquidityRange;

        vm.prank(manager);
        module.rebalance(liquidityRanges);

        // #endregion do rebalance.

        // #region move price.

        IPoolManager.SwapParams memory params = IPoolManager
            .SwapParams({
            zeroForOne: false,
            amountSpecified: 100,
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(tickUpper)
        });

        tick = tickUpper;

        tickLower = (tick / 10) * 10 - (100 * 10);
        tickUpper = (tick / 10) * 10 + (100 * 10);

        range = IUniV4StandardModule.Range({
            tickLower: tickLower,
            tickUpper: tickUpper
        });

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            TickMath.getSqrtPriceAtTick(tick),
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            init0 - 1000,
            init1 - 1000
        );

        liquidityRange = IUniV4StandardModule.LiquidityRange({
            range: range,
            liquidity: SafeCast.toInt128(
                SafeCast.toInt256(uint256(liquidity))
            )
        });

        liquidityRanges[0] = liquidityRange;

        {
            PoolId poolId = poolKey.toId();

            (uint160 oldPrice,,,) =
                IPoolManager(address(poolManager)).getSlot0(poolId);
            console.log("Old Price : %d", oldPrice);

            vm.prank(address(manager));
            module.movePrice(params, liquidityRanges);

            (uint160 newPrice,,,) =
                IPoolManager(address(poolManager)).getSlot0(poolId);

            // #endregion move price.

            // #region withdraw.

            console.log("New Price : %d", newPrice);
            console.log(
                "Expected New Price : %d",
                TickMath.getSqrtPriceAtTick(tick)
            );

            assertEq(newPrice, TickMath.getSqrtPriceAtTick(tick));
        }

        {
            address receiver =
                vm.addr(uint256(keccak256(abi.encode("Receiver"))));
            vm.prank(metaVault);
            module.withdraw(receiver, BASE);

            /// @dev remove some wei due to uniswap v4 actions that are rounding down.
            assertGe(
                IERC20Metadata(USDC).balanceOf(receiver), init0 - 5
            );
            assertGe(
                IERC20Metadata(WETH).balanceOf(receiver), init1 - 5
            );
        }

        // #endregion withdraw.
    }

    // #endregion test movePrice.
}
