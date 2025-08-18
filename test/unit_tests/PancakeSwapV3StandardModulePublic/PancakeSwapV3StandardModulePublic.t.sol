// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry imports
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry imports

// #region module imports
import {PancakeSwapV3StandardModulePublic} from
    "../../../src/modules/PancakeSwapV3StandardModulePublic.sol";
import {PancakeSwapV3StandardModule} from
    "../../../src/abstracts/PancakeSwapV3StandardModule.sol";
import {IPancakeSwapV3StandardModule} from
    "../../../src/interfaces/IPancakeSwapV3StandardModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePublic} from
    "../../../src/interfaces/IArrakisLPModulePublic.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {
    BASE,
    PIPS,
    TEN_PERCENT,
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";
import {
    RebalanceParams,
    MintReturnValues
} from "../../../src/structs/SPancakeSwapV3.sol";
import {
    ModifyPosition,
    SwapPayload
} from "../../../src/structs/SUniswapV3.sol";
// #endregion module imports

// #region openzeppelin imports
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// #endregion openzeppelin imports

// #region pancakeswap imports
import {INonfungiblePositionManagerPancake} from
    "../../../src/interfaces/INonfungiblePositionManagerPancake.sol";
import {IUniswapV3FactoryVariant} from
    "../../../src/interfaces/IUniswapV3FactoryVariant.sol";
import {IUniswapV3PoolVariant} from
    "../../../src/interfaces/IUniswapV3PoolVariant.sol";
import {IUniswapV3Pool} from
    "../../../src/interfaces/IUniswapV3Pool.sol";
import {IMasterChefV3} from
    "../../../src/interfaces/IMasterChefV3.sol";
// #endregion pancakeswap imports

// #region math libraries
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
// #endregion math libraries

// #region mock imports
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleWrapperMock} from "./mocks/OracleWrapperMock.sol";
// #endregion mock imports

contract PancakeSwapV3StandardModulePublicTest is TestWrapper {
    // #region constants
    address public constant WETH =
        0x2170Ed0880ac9A755fd29B2688956BD959F933F8; // token0
    address public constant USDT =
        0x55d398326f99059fF775485246999027B3197955; // token1 (18 decimals on BNB)
    address public constant CAKE =
        0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    address public constant PANCAKE_V3_FACTORY =
        0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865;
    address public constant PANCAKE_V3_NFT_MANAGER =
        0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
    address public constant PANCAKE_V3_MASTERCHEF =
        0x556B9306565093C855AEA9AE92A594704c2Cd59e;
    /// @dev this pool has cake farming (block number : 57991057)
    address public constant PANCAKE_V3_POOL =
        0xBe141893E4c6AD9272e8C04BAB7E6a10604501a5;
    uint24 public constant POOL_FEE = 500;
    uint256 public constant INIT_0 = 1e18; // WETH (token0)
    uint256 public constant INIT_1 = 4340e18; // USDT (token1) - 18 decimals on BNB
    uint24 public constant MAX_SLIPPAGE = 1000; // 1%
    // #endregion constants

    // #region state variables
    PancakeSwapV3StandardModulePublic public module;
    ArrakisMetaVaultMock public metaVault;
    GuardianMock public guardian;
    OracleWrapperMock public oracle;

    address public manager;
    address public pauser;
    address public owner;
    address public cakeReceiver;
    address public depositor;
    address public receiver;
    // #endregion state variables

    // #region setup
    function setUp() public {
        _reset(vm.envString("BSC_RPC_URL"), 57_991_057);

        // Setup addresses
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        cakeReceiver =
            vm.addr(uint256(keccak256(abi.encode("CakeReceiver"))));
        depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // Deploy mock contracts (only ArrakisMetaVault, Oracle, Guardian)
        metaVault = new ArrakisMetaVaultMock(manager, owner);
        metaVault.setTokens(WETH, USDT); // token0=WETH, token1=USDT

        guardian = new GuardianMock(pauser);
        oracle = new OracleWrapperMock();

        // Deploy module using real PancakeSwap contracts
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            oracle,
            INIT_0,
            INIT_1,
            MAX_SLIPPAGE,
            cakeReceiver,
            POOL_FEE,
            address(metaVault)
        );

        module = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        // Set manager fee
        vm.prank(manager);
        module.setManagerFeePIPS(1000); // 10%

        // Fund test accounts
        deal(WETH, depositor, 100e18); // token0
        deal(USDT, depositor, 100_000e18); // token1 (18 decimals on BNB)
    }
    // #endregion setup

    // #region deployment tests
    function test_Constructor() public {
        assertEq(module.nftPositionManager(), PANCAKE_V3_NFT_MANAGER);
        assertEq(module.factory(), PANCAKE_V3_FACTORY);
        assertEq(module.CAKE(), CAKE);
        assertEq(module.masterChefV3(), PANCAKE_V3_MASTERCHEF);
    }

    function test_Initialize() public {
        assertEq(address(module.oracle()), address(oracle));
        assertEq(module.maxSlippage(), MAX_SLIPPAGE);
        assertEq(module.cakeReceiver(), cakeReceiver);
        assertEq(address(module.metaVault()), address(metaVault));
        assertEq(address(module.token0()), WETH);
        assertEq(address(module.token1()), USDT);

        (uint256 init0, uint256 init1) = module.getInits();
        assertEq(init0, INIT_0);
        assertEq(init1, INIT_1);
    }

    function testRevert_Initialize_AddressZero() public {
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            IOracleWrapper(address(0)), // Zero oracle
            INIT_0,
            INIT_1,
            MAX_SLIPPAGE,
            cakeReceiver,
            POOL_FEE,
            address(metaVault)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new ERC1967Proxy(implementation, data);
    }

    function testRevert_Initialize_MaxSlippageGtTenPercent() public {
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            oracle,
            INIT_0,
            INIT_1,
            TEN_PERCENT + 1, // Too high slippage
            cakeReceiver,
            POOL_FEE,
            address(metaVault)
        );

        vm.expectRevert(
            IPancakeSwapV3StandardModule
                .MaxSlippageGtTenPercent
                .selector
        );
        new ERC1967Proxy(implementation, data);
    }

    function testRevert_Initialize_InitsAreZeros() public {
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            oracle,
            0, // Zero init0
            0, // Zero init1
            MAX_SLIPPAGE,
            cakeReceiver,
            POOL_FEE,
            address(metaVault)
        );

        vm.expectRevert(IArrakisLPModule.InitsAreZeros.selector);
        new ERC1967Proxy(implementation, data);
    }

    function testRevert_Initialize_NativeCoinNotAllowed() public {
        ArrakisMetaVaultMock nativeVault =
            new ArrakisMetaVaultMock(manager, owner);
        nativeVault.setTokens(NATIVE_COIN, WETH);

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            oracle,
            INIT_0,
            INIT_1,
            MAX_SLIPPAGE,
            cakeReceiver,
            POOL_FEE,
            address(nativeVault)
        );

        vm.expectRevert(
            IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector
        );
        new ERC1967Proxy(implementation, data);
    }
    // #endregion deployment tests

    // #region getter tests
    function test_Id() public {
        assertEq(
            module.id(),
            0x918c66e50fd8ae37316bc2160d5f23b3f5d59ccd1972c9a515dc2f8ac22875b6
        );
    }

    function test_Guardian() public {
        assertEq(module.guardian(), pauser);
    }

    function test_TokenIds() public {
        uint256[] memory tokenIds = module.tokenIds();
        assertEq(tokenIds.length, 0);
    }

    function test_TotalUnderlying() public {
        (uint256 amount0, uint256 amount1) = module.totalUnderlying();
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_TotalUnderlyingAtPrice() public {
        uint160 priceX96 = 79_228_162_514_264_337_593_543_950_336; // sqrt(1) * 2^96
        (uint256 amount0, uint256 amount1) =
            module.totalUnderlyingAtPrice(priceX96);
        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    function test_ManagerBalance0() public {
        uint256 balance = module.managerBalance0();
        assertEq(balance, 0);
    }

    function test_ManagerBalance1() public {
        uint256 balance = module.managerBalance1();
        assertEq(balance, 0);
    }

    function test_CakeManagerBalance() public {
        uint256 balance = module.cakeManagerBalance();
        assertEq(balance, 0);
    }

    function test_NotFirstDeposit() public {
        assertFalse(module.notFirstDeposit());
    }
    // #endregion getter tests

    // #region deposit tests
    function test_Deposit() public {
        deal(WETH, depositor, INIT_0);
        deal(USDT, depositor, INIT_1);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(module), INIT_0);
        IERC20Metadata(USDT).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit IArrakisLPModulePublic.LogDeposit(
            depositor, BASE, INIT_0, INIT_1
        );

        vm.prank(address(metaVault));
        (uint256 amount0, uint256 amount1) =
            module.deposit(depositor, BASE);

        assertEq(amount0, INIT_0);
        assertEq(amount1, INIT_1);
        assertTrue(module.notFirstDeposit());
    }

    function testRevert_Deposit_OnlyMetaVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );
        module.deposit(depositor, BASE);
    }

    function testRevert_Deposit_ProportionZero() public {
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);
        vm.prank(address(metaVault));
        module.deposit(depositor, 0);
    }

    function testRevert_Deposit_NativeCoinNotAllowed() public {
        deal(address(metaVault), 1 ether);

        vm.expectRevert(
            IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector
        );
        vm.prank(address(metaVault));
        module.deposit{value: 1 ether}(depositor, BASE);
    }

    function test_Deposit_SubsequentDeposits() public {
        deal(WETH, depositor, INIT_0);
        deal(USDT, depositor, INIT_1);

        // Record initial module balances
        uint256 moduleBalanceBefore0 =
            IERC20Metadata(WETH).balanceOf(address(module));
        uint256 moduleBalanceBefore1 =
            IERC20Metadata(USDT).balanceOf(address(module));

        // Record initial depositor balances
        uint256 depositorBalanceBefore0 =
            IERC20Metadata(WETH).balanceOf(depositor);
        uint256 depositorBalanceBefore1 =
            IERC20Metadata(USDT).balanceOf(depositor);

        // First deposit
        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(module), INIT_0);
        IERC20Metadata(USDT).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit IArrakisLPModulePublic.LogDeposit(
            depositor, BASE, INIT_0, INIT_1
        );

        vm.prank(address(metaVault));
        (uint256 amount0First, uint256 amount1First) =
            module.deposit(depositor, BASE);

        // Assertions for first deposit
        assertEq(
            amount0First,
            INIT_0,
            "First deposit amount0 should equal INIT_0"
        );
        assertEq(
            amount1First,
            INIT_1,
            "First deposit amount1 should equal INIT_1"
        );
        assertTrue(
            module.notFirstDeposit(),
            "notFirstDeposit should be true after first deposit"
        );

        // Check token transfers for first deposit
        assertEq(
            IERC20Metadata(WETH).balanceOf(address(module)),
            moduleBalanceBefore0 + INIT_0,
            "Module WETH balance should increase by INIT_0"
        );
        assertEq(
            IERC20Metadata(USDT).balanceOf(address(module)),
            moduleBalanceBefore1 + INIT_1,
            "Module USDT balance should increase by INIT_1"
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(depositor),
            depositorBalanceBefore0 - INIT_0,
            "Depositor WETH balance should decrease by INIT_0"
        );
        assertEq(
            IERC20Metadata(USDT).balanceOf(depositor),
            depositorBalanceBefore1 - INIT_1,
            "Depositor USDT balance should decrease by INIT_1"
        );

        // Setup for second deposit
        deal(WETH, depositor, 2e18);
        deal(USDT, depositor, 2000e18);

        // Record balances before second deposit
        uint256 moduleBalanceBeforeSecond0 =
            IERC20Metadata(WETH).balanceOf(address(module));
        uint256 moduleBalanceBeforeSecond1 =
            IERC20Metadata(USDT).balanceOf(address(module));
        uint256 depositorBalanceBeforeSecond0 =
            IERC20Metadata(WETH).balanceOf(depositor);
        uint256 depositorBalanceBeforeSecond1 =
            IERC20Metadata(USDT).balanceOf(depositor);

        // Second deposit with proportion
        uint256 proportion = BASE / 2; // 50%

        // For subsequent deposits, the amounts are calculated based on current underlying
        // Since we don't have actual positions, totalUnderlying should return (0,0)
        // So the proportion-based calculation should work on the module's token balances
        (uint256 totalUnderlying0, uint256 totalUnderlying1) =
            module.totalUnderlying();

        // Calculate expected amounts for second deposit (based on proportion of total underlying)
        uint256 expectedAmount0Second = FullMath.mulDivRoundingUp(
            totalUnderlying0, proportion, BASE
        );
        uint256 expectedAmount1Second = FullMath.mulDivRoundingUp(
            totalUnderlying1, proportion, BASE
        );

        deal(WETH, depositor, expectedAmount0Second);
        deal(USDT, depositor, expectedAmount1Second);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(module), expectedAmount0Second);
        IERC20Metadata(USDT).approve(address(module), expectedAmount1Second);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit IArrakisLPModulePublic.LogDeposit(
            depositor,
            proportion,
            expectedAmount0Second,
            expectedAmount1Second
        );

        vm.prank(address(metaVault));
        (uint256 amount0Second, uint256 amount1Second) =
            module.deposit(depositor, proportion);

        // Assertions for second deposit
        assertEq(
            amount0Second,
            expectedAmount0Second,
            "Second deposit amount0 should match expected calculation"
        );
        assertEq(
            amount1Second,
            expectedAmount1Second,
            "Second deposit amount1 should match expected calculation"
        );
        assertTrue(
            module.notFirstDeposit(),
            "notFirstDeposit should remain true after second deposit"
        );

        // Check token transfers for second deposit
        assertEq(
            IERC20Metadata(WETH).balanceOf(address(module)),
            moduleBalanceBeforeSecond0 + amount0Second,
            "Module WETH balance should increase by second deposit amount"
        );
        assertEq(
            IERC20Metadata(USDT).balanceOf(address(module)),
            moduleBalanceBeforeSecond1 + amount1Second,
            "Module USDT balance should increase by second deposit amount"
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(depositor),
            0,
            "Depositor WETH balance should decrease by second deposit amount"
        );
        assertEq(
            IERC20Metadata(USDT).balanceOf(depositor),
            0,
            "Depositor USDT balance should decrease by second deposit amount"
        );
    }

    function test_Deposit_AfterRebalance() public {
        // Step 1: Initial deposit
        deal(WETH, depositor, INIT_0);
        deal(USDT, depositor, INIT_1);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(module), INIT_0);
        IERC20Metadata(USDT).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.prank(address(metaVault));
        (uint256 amount0First, uint256 amount1First) =
            module.deposit(depositor, BASE);

        // Verify first deposit
        assertEq(
            amount0First,
            INIT_0,
            "First deposit amount0 should equal INIT_0"
        );
        assertEq(
            amount1First,
            INIT_1,
            "First deposit amount1 should equal INIT_1"
        );
        assertTrue(
            module.notFirstDeposit(),
            "notFirstDeposit should be true after first deposit"
        );

        // Step 2: Manager performs rebalance creating two positions
        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(module.pool()).slot0();

        // Calculate token amounts (50% each position)
        uint256 balance0 =
            IERC20Metadata(WETH).balanceOf(address(module));
        uint256 balance1 =
            IERC20Metadata(USDT).balanceOf(address(module));

        // Create rebalance params with two mint positions
        INonfungiblePositionManagerPancake.MintParams[] memory
            mintParams =
                new INonfungiblePositionManagerPancake.MintParams[](2);

        // Position 1: 1% range using 50% of tokens
        {
            (int24 lowerTick1, int24 upperTick1) =
                _calculateTickRange(sqrtPriceX96, 1);
            mintParams[0] = INonfungiblePositionManagerPancake
                .MintParams({
                token0: WETH,
                token1: USDT,
                fee: POOL_FEE,
                tickLower: lowerTick1,
                tickUpper: upperTick1,
                amount0Desired: balance0 / 2,
                amount1Desired: balance1 / 2,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(module),
                deadline: block.timestamp + 1 hours
            });
        }

        // Position 2: 2% range using remaining 50% of tokens
        {
            (int24 lowerTick2, int24 upperTick2) =
                _calculateTickRange(sqrtPriceX96, 2);
            mintParams[1] = INonfungiblePositionManagerPancake
                .MintParams({
                token0: WETH,
                token1: USDT,
                fee: POOL_FEE,
                tickLower: lowerTick2,
                tickUpper: upperTick2,
                amount0Desired: balance0 / 2,
                amount1Desired: balance1 / 2,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(module),
                deadline: block.timestamp + 1 hours
            });
        }

        RebalanceParams memory rebalanceParams = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                payload: "",
                router: address(0),
                amountIn: 0,
                expectedMinReturn: 0,
                zeroForOne: false
            }),
            mintParams: mintParams,
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 0,
            minDeposit1: 0
        });

        vm.prank(manager);
        module.rebalance(rebalanceParams);

        // Verify positions were created
        uint256[] memory tokenIds = module.tokenIds();
        assertEq(
            tokenIds.length, 2, "Should have at least 2 positions"
        );

        (
            uint256 depositorBalance0Before,
            uint256 depositorBalance1Before
        ) = module.totalUnderlying();

        // Step 3: Test second deposit works after rebalance
        // Give depositor enough tokens for the proportional deposit
        deal(WETH, depositor, depositorBalance0Before / 4); // 2 WETH
        deal(USDT, depositor, depositorBalance1Before / 4); // 5000 USDT

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(
            address(module), depositorBalance0Before / 4
        );
        IERC20Metadata(USDT).approve(
            address(module), depositorBalance1Before / 4
        );
        vm.stopPrank();

        // Calculate expected amounts for second deposit based on total underlying
        uint256 proportion = (BASE / 4) - 1; // 25%

        // Store balances before second deposit
        depositorBalance0Before =
            IERC20Metadata(WETH).balanceOf(depositor);
        depositorBalance1Before =
            IERC20Metadata(USDT).balanceOf(depositor);
        (uint256 moduleBalance0Before, uint256 moduleBalance1Before) =
            module.totalUnderlying();

        // Execute second deposit - this should work regardless of whether positions were created
        vm.prank(address(metaVault));
        (uint256 amount0Second, uint256 amount1Second) =
            module.deposit(depositor, proportion);

        // Verify deposit completed successfully (amounts may be 0 if no positions exist)
        // The key test is that the deposit doesn't revert and handles the post-rebalance state correctly

        // Verify state remains consistent
        assertTrue(
            module.notFirstDeposit(),
            "notFirstDeposit should remain true after second deposit"
        );

        (
            uint256 newModuleBalance0Before,
            uint256 newModuleBalance1Before
        ) = module.totalUnderlying();

        // Verify token transfers occurred correctly
        assertEq(
            newModuleBalance0Before,
            moduleBalance0Before + amount0Second,
            "Module WETH balance should increase by deposit amount"
        );
        assertEq(
            newModuleBalance1Before,
            moduleBalance1Before + amount1Second,
            "Module USDT balance should increase by deposit amount"
        );
        assertEq(
            IERC20Metadata(WETH).balanceOf(depositor),
            depositorBalance0Before - amount0Second,
            "Depositor WETH balance should decrease by deposit amount"
        );
        assertEq(
            IERC20Metadata(USDT).balanceOf(depositor),
            depositorBalance1Before - amount1Second,
            "Depositor USDT balance should decrease by deposit amount"
        );
        // 31630597104541167 != 273722947828405873
        // 31630597104541167 != 273722947828405873

        // Test successfully completed the deposit -> rebalance -> deposit flow
    }

    // #endregion deposit tests

    // #region rebalance tests.

    function test_deposit_rebalance_deposit_swap_inventory_deposit_swap_on_pool_withdraw() public {
        PancakeSwapV3StandardModulePublic customModule = _setupCustomModule();
        _performInitialDepositAndRebalance(customModule);
        address depositor2 = _performSecondDeposit(customModule);
        _performBurnRebalance(customModule);
        _performDirectPoolSwap(customModule); // Direct pool swap: 0.01 WETH to USDT
        _performTimeAdvanceAndPoolSwap(customModule);
        _performWithdrawalAndVerify(customModule, depositor2);
    }

    function _setupCustomModule() internal returns (PancakeSwapV3StandardModulePublic) {
        uint256 customInit0 = 15e17; // 1.5 WETH
        uint256 customInit1 = 2170e18; // 2170 USDT
        
        ArrakisMetaVaultMock customMetaVault = new ArrakisMetaVaultMock(manager, owner);
        customMetaVault.setTokens(WETH, USDT);
        
        address customImplementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                PANCAKE_V3_NFT_MANAGER,
                PANCAKE_V3_FACTORY,
                CAKE,
                PANCAKE_V3_MASTERCHEF
            )
        );

        bytes memory customData = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            oracle,
            customInit0,
            customInit1,
            MAX_SLIPPAGE,
            cakeReceiver,
            POOL_FEE,
            address(customMetaVault)
        );

        PancakeSwapV3StandardModulePublic customModule = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(customImplementation, customData)))
        );

        vm.prank(manager);
        customModule.setManagerFeePIPS(1000); // 1%
        
        return customModule;
    }

    function _performInitialDepositAndRebalance(PancakeSwapV3StandardModulePublic customModule) internal {
        uint256 customInit0 = 15e17; // 1.5 WETH
        uint256 customInit1 = 2170e18; // 2170 USDT

        // Check initial state
        (uint256 preDepositUnderlying0, uint256 preDepositUnderlying1) = customModule.totalUnderlying();
        assertEq(preDepositUnderlying0, 0, "Initial underlying WETH should be 0");
        assertEq(preDepositUnderlying1, 0, "Initial underlying USDT should be 0");
        assertEq(customModule.managerBalance0(), 0, "Initial manager WETH balance should be 0");
        assertEq(customModule.managerBalance1(), 0, "Initial manager USDT balance should be 0");
        assertEq(customModule.cakeManagerBalance(), 0, "Initial CAKE balance should be 0");

        deal(WETH, depositor, customInit0);
        deal(USDT, depositor, customInit1);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(customModule), customInit0);
        IERC20Metadata(USDT).approve(address(customModule), customInit1);
        vm.stopPrank();

        vm.prank(address(customModule.metaVault()));
        (uint256 amount0First, uint256 amount1First) = customModule.deposit(depositor, BASE);

        assertEq(amount0First, customInit0, "First deposit amount0 should equal custom INIT_0");
        assertEq(amount1First, customInit1, "First deposit amount1 should equal custom INIT_1");

        // Check balances after deposit, before rebalance
        (uint256 postDepositUnderlying0, uint256 postDepositUnderlying1) = customModule.totalUnderlying();
        assertEq(postDepositUnderlying0, customInit0, "Underlying WETH should equal deposit");
        assertEq(postDepositUnderlying1, customInit1, "Underlying USDT should equal deposit");
        assertEq(customModule.managerBalance0(), 0, "Manager WETH balance should still be 0 after deposit");
        assertEq(customModule.managerBalance1(), 0, "Manager USDT balance should still be 0 after deposit");

        // Create initial rebalance
        _createTwoPositionsRebalance(customModule);
        
        uint256[] memory tokenIds = customModule.tokenIds();
        assertEq(tokenIds.length, 2, "Should have 2 positions after rebalance");

        // Check balances after rebalance
        (uint256 postRebalanceUnderlying0, uint256 postRebalanceUnderlying1) = customModule.totalUnderlying();
        assertGt(postRebalanceUnderlying0, 0, "Should have WETH underlying after rebalance");
        assertGt(postRebalanceUnderlying1, 0, "Should have USDT underlying after rebalance");
        assertEq(customModule.managerBalance0(), 0, "Manager WETH balance should be 0 after initial rebalance");
        assertEq(customModule.managerBalance1(), 0, "Manager USDT balance should be 0 after initial rebalance");
    }

    function _createTwoPositionsRebalance(PancakeSwapV3StandardModulePublic customModule) internal {
        (uint160 sqrtPriceX96,,,,,,) = IUniswapV3PoolVariant(customModule.pool()).slot0();
        
        uint256 balance0 = IERC20Metadata(WETH).balanceOf(address(customModule));
        uint256 balance1 = IERC20Metadata(USDT).balanceOf(address(customModule));
        
        INonfungiblePositionManagerPancake.MintParams[] memory mintParams = 
            new INonfungiblePositionManagerPancake.MintParams[](2);
        
        (int24 lowerTick1, int24 upperTick1) = _calculateTickRange(sqrtPriceX96, 1);
        mintParams[0] = INonfungiblePositionManagerPancake.MintParams({
            token0: WETH,
            token1: USDT,
            fee: POOL_FEE,
            tickLower: lowerTick1,
            tickUpper: upperTick1,
            amount0Desired: balance0 / 2,
            amount1Desired: balance1 / 2,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(customModule),
            deadline: block.timestamp + 1 hours
        });
        
        (int24 lowerTick2, int24 upperTick2) = _calculateTickRange(sqrtPriceX96, 2);
        mintParams[1] = INonfungiblePositionManagerPancake.MintParams({
            token0: WETH,
            token1: USDT,
            fee: POOL_FEE,
            tickLower: lowerTick2,
            tickUpper: upperTick2,
            amount0Desired: balance0 / 2,
            amount1Desired: balance1 / 2,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(customModule),
            deadline: block.timestamp + 1 hours
        });

        RebalanceParams memory rebalanceParams = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                payload: "",
                router: address(0),
                amountIn: 0,
                expectedMinReturn: 0,
                zeroForOne: false
            }),
            mintParams: mintParams,
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 0,
            minDeposit1: 0
        });

        vm.prank(manager);
        customModule.rebalance(rebalanceParams);
    }

    function _performSecondDeposit(PancakeSwapV3StandardModulePublic customModule) internal returns (address depositor2) {
        depositor2 = vm.addr(uint256(keccak256(abi.encode("Depositor2"))));
        
        // Record balances before second deposit
        (uint256 preSecondDepositUnderlying0, uint256 preSecondDepositUnderlying1) = customModule.totalUnderlying();
        uint256 preSecondDepositManager0 = customModule.managerBalance0();
        uint256 preSecondDepositManager1 = customModule.managerBalance1();
        uint256 preSecondDepositCake = customModule.cakeManagerBalance();
        
        uint256 depositAmount0 = preSecondDepositUnderlying0 / 3;
        uint256 depositAmount1 = preSecondDepositUnderlying1 / 3;
        
        deal(WETH, depositor2, depositAmount0);
        deal(USDT, depositor2, depositAmount1);

        vm.startPrank(depositor2);
        IERC20Metadata(WETH).approve(address(customModule), depositAmount0);
        IERC20Metadata(USDT).approve(address(customModule), depositAmount1);
        vm.stopPrank();

        uint256 proportion = FullMath.mulDiv(depositAmount0, BASE, preSecondDepositUnderlying0);
        
        vm.prank(address(customModule.metaVault()));
        (uint256 amount0Second, uint256 amount1Second) = customModule.deposit(depositor2, proportion);

        assertGt(amount0Second, 0, "Second deposit should have non-zero amount0");
        assertGt(amount1Second, 0, "Second deposit should have non-zero amount1");

        // Check balances after second deposit
        (uint256 postSecondDepositUnderlying0, uint256 postSecondDepositUnderlying1) = customModule.totalUnderlying();
        assertGt(postSecondDepositUnderlying0, preSecondDepositUnderlying0, "Underlying WETH should increase after second deposit");
        assertGt(postSecondDepositUnderlying1, preSecondDepositUnderlying1, "Underlying USDT should increase after second deposit");
        
        // Manager balances should not change from deposits alone
        assertEq(customModule.managerBalance0(), preSecondDepositManager0, "Manager WETH balance should not change from deposit");
        assertEq(customModule.managerBalance1(), preSecondDepositManager1, "Manager USDT balance should not change from deposit");
        assertEq(customModule.cakeManagerBalance(), preSecondDepositCake, "CAKE balance should not change from deposit");
    }

    function _performBurnRebalance(PancakeSwapV3StandardModulePublic customModule) internal {
        // Record balances before burn rebalance
        (uint256 preBurnUnderlying0, uint256 preBurnUnderlying1) = customModule.totalUnderlying();
        uint256 preBurnManager0 = customModule.managerBalance0();
        uint256 preBurnManager1 = customModule.managerBalance1();
        uint256 preBurnCake = customModule.cakeManagerBalance();
        
        uint256[] memory tokenIds = customModule.tokenIds();
        require(tokenIds.length >= 2, "Should have at least 2 positions");
        assertEq(tokenIds.length, 2, "Should have exactly 2 positions before burn rebalance");

        ModifyPosition[] memory decreasePositions = new ModifyPosition[](1);
        decreasePositions[0] = ModifyPosition({
            tokenId: tokenIds[0],
            proportion: BASE
        });

        ModifyPosition[] memory increasePositions = new ModifyPosition[](1);
        increasePositions[0] = ModifyPosition({
            tokenId: tokenIds[1],
            proportion: BASE / 2
        });

        RebalanceParams memory burnRebalanceParams = RebalanceParams({
            decreasePositions: decreasePositions,
            increasePositions: increasePositions,
            swapPayload: SwapPayload({
                payload: "",
                router: address(0),
                amountIn: 0,
                expectedMinReturn: 0,
                zeroForOne: false
            }),
            mintParams: new INonfungiblePositionManagerPancake.MintParams[](0),
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 0,
            minDeposit1: 0
        });

        vm.prank(manager);
        customModule.rebalance(burnRebalanceParams);

        // Verify burn rebalance results
        uint256[] memory newTokenIds = customModule.tokenIds();
        assertEq(newTokenIds.length, 1, "Should have 1 position after burn rebalance");
        
        // Check balances after burn rebalance
        (uint256 postBurnUnderlying0, uint256 postBurnUnderlying1) = customModule.totalUnderlying();
        assertGt(postBurnUnderlying0, 0, "Should still have WETH underlying after burn rebalance");
        assertGt(postBurnUnderlying1, 0, "Should still have USDT underlying after burn rebalance");
        
        // Manager balances should be 0 or stay the same (no fees from burning)
        assertEq(customModule.managerBalance0(), preBurnManager0, "Manager WETH balance should not change from burn rebalance");
        assertEq(customModule.managerBalance1(), preBurnManager1, "Manager USDT balance should not change from burn rebalance");
        assertGe(customModule.cakeManagerBalance(), preBurnCake, "CAKE balance should not decrease from burn rebalance");
    }

    function _performDirectPoolSwap(PancakeSwapV3StandardModulePublic customModule) internal {
        // Direct pool swap: 0.01 WETH to USDT
        address poolAddress = customModule.pool();
        uint256 swapAmountWETH = 0.01e18;
        
        // Give this test contract the WETH to swap
        deal(WETH, address(this), swapAmountWETH);
        
        // Approve the pool to spend WETH
        IERC20Metadata(WETH).approve(poolAddress, swapAmountWETH);
        
        // Record test contract balances before swap
        uint256 wethBalanceBefore = IERC20Metadata(WETH).balanceOf(address(this));
        uint256 usdtBalanceBefore = IERC20Metadata(USDT).balanceOf(address(this));
        
        // Perform the swap directly on the pool
        // zeroForOne = true (WETH to USDT), amountSpecified = exact input amount
        IUniswapV3Pool(poolAddress).swap(
            address(this), // recipient
            true, // zeroForOne (WETH to USDT)
            int256(swapAmountWETH), // amountSpecified (exact input)
            TickMath.MIN_SQRT_RATIO + 1, // sqrtPriceLimitX96
            "" // data
        );
        
        // Verify the swap occurred on test contract
        uint256 wethBalanceAfter = IERC20Metadata(WETH).balanceOf(address(this));
        uint256 usdtBalanceAfter = IERC20Metadata(USDT).balanceOf(address(this));
        
        assertEq(wethBalanceAfter, wethBalanceBefore - swapAmountWETH, "WETH should be consumed in swap");
        assertGt(usdtBalanceAfter, usdtBalanceBefore, "USDT should be received from swap");
        
        // Log swap details
        // console.log("Direct pool swap completed:");
        // console.log("- Swapped WETH:", swapAmountWETH);
        // console.log("- Received USDT:", usdtBalanceAfter - usdtBalanceBefore);
    }

    function _performTimeAdvanceAndPoolSwap(PancakeSwapV3StandardModulePublic customModule) internal {
        // Move forward by one day
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 7200);

        // Direct pool swap
        address poolAddress = customModule.pool();
        uint256 swapAmountWETH = 0.01e18;
        
        deal(WETH, address(this), swapAmountWETH);
        IERC20Metadata(WETH).approve(poolAddress, swapAmountWETH);

        IUniswapV3Pool(poolAddress).swap(
            address(this),
            true, // zeroForOne (WETH -> USDT)
            int256(swapAmountWETH),
            TickMath.MIN_SQRT_RATIO + 1,
            ""
        );

        // Move forward by another day
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 7200);

        uint256 managerBalance0 = customModule.managerBalance0();
        uint256 managerBalance1 = customModule.managerBalance1();

        assertGt(managerBalance0, 0, "Manager should have WETH balance after time advance and swap");
        assertEq(managerBalance1, 0, "Manager should have USDT balance after time advance and swap");
    }

    function _performWithdrawalAndVerify(PancakeSwapV3StandardModulePublic customModule, address depositor2) internal {
        _verifyPreWithdrawState(customModule);
        
        uint256 withdrawProportion = BASE / 3; // 33.33%
        
        // Perform withdrawal and verify results
        vm.prank(address(customModule.metaVault()));
        (uint256 withdrawAmount0, uint256 withdrawAmount1) = customModule.withdraw(depositor2, withdrawProportion);
        
        _verifyPostWithdrawState(customModule, depositor2, withdrawAmount0, withdrawAmount1);
    }
    
    function _verifyPreWithdrawState(PancakeSwapV3StandardModulePublic customModule) internal view {
        // Check manager wallet balances are zero before withdrawal
        assertEq(IERC20Metadata(WETH).balanceOf(manager), 0, "Manager wallet WETH should be 0 before withdrawal");
        assertEq(IERC20Metadata(USDT).balanceOf(manager), 0, "Manager wallet USDT should be 0 before withdrawal");
        
        // Verify module has underlying assets
        (uint256 underlying0, uint256 underlying1) = customModule.totalUnderlying();
        assertGt(underlying0, 0, "Module should have WETH underlying before withdrawal");
        assertGt(underlying1, 0, "Module should have USDT underlying before withdrawal");
    }
    
    function _verifyPostWithdrawState(
        PancakeSwapV3StandardModulePublic customModule, 
        address depositor2,
        uint256 withdrawAmount0,
        uint256 withdrawAmount1
    ) internal {
        // Verify withdrawal amounts
        assertGt(withdrawAmount0, 0, "Withdrawal amount0 should be positive");
        assertGt(withdrawAmount1, 0, "Withdrawal amount1 should be positive");
        
        // Check manager received fees in wallet
        assertGt(IERC20Metadata(WETH).balanceOf(manager), 0, "Manager should receive WETH fees");
        assertEq(IERC20Metadata(USDT).balanceOf(manager), 0, "Manager USDT wallet should stay 0");
        
        // Check depositor2 received tokens
        assertGt(IERC20Metadata(WETH).balanceOf(depositor2), 0, "Depositor2 should receive WETH");
        assertGt(IERC20Metadata(USDT).balanceOf(depositor2), 0, "Depositor2 should receive USDT");
        
        // Verify final module state
        (uint256 finalUnderlying0, uint256 finalUnderlying1) = customModule.totalUnderlying();
        assertGt(finalUnderlying0 + finalUnderlying1, 0, "Module should have remaining underlying");
        
        // Manager internal balances should be 0 after withdrawal (fees claimed)
        assertEq(customModule.managerBalance0(), 0, "Manager internal WETH balance should be 0 after withdrawal");
        assertEq(customModule.managerBalance1(), 0, "Manager internal USDT balance should be 0 after withdrawal");
        
        // CAKE rewards should have accumulated
        assertGt(customModule.cakeManagerBalance(), 0, "Should have accumulated CAKE rewards");
        assertEq(customModule.managerFeePIPS(), 1000, "Manager fee should remain 1000 (10%)");
        
        // Log final balances for verification
        // console.log("Final module underlying WETH:", finalUnderlying0);
        // console.log("Final module underlying USDT:", finalUnderlying1);
        // console.log("Final manager internal WETH balance:", customModule.managerBalance0());
        // console.log("Final manager internal USDT balance:", customModule.managerBalance1());
        // console.log("Final manager wallet WETH balance:", IERC20Metadata(WETH).balanceOf(manager));
        // console.log("Final manager wallet USDT balance:", IERC20Metadata(USDT).balanceOf(manager));
        // console.log("Final CAKE balance:", customModule.cakeManagerBalance());
        // console.log("Withdrawer received WETH:", withdrawAmount0);
        // console.log("Withdrawer received USDT:", withdrawAmount1);
    }

    // #endregion rebalance tests.

    // #region withdraw tests
    function testRevert_Withdraw_OnlyMetaVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );
        module.withdraw(receiver, BASE);
    }

    function testRevert_Withdraw_AddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(address(metaVault));
        module.withdraw(address(0), BASE);
    }

    function testRevert_Withdraw_ProportionZero() public {
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);
        vm.prank(address(metaVault));
        module.withdraw(receiver, 0);
    }

    function testRevert_Withdraw_ProportionGtBASE() public {
        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);
        vm.prank(address(metaVault));
        module.withdraw(receiver, BASE + 1);
    }
    // #endregion withdraw tests

    // #region pause/unpause tests
    function test_Pause() public {
        vm.prank(pauser);
        module.pause();
        assertTrue(module.paused());
    }

    function test_Unpause() public {
        vm.prank(pauser);
        module.pause();
        assertTrue(module.paused());

        vm.prank(pauser);
        module.unpause();
        assertFalse(module.paused());
    }

    function testRevert_Pause_OnlyGuardian() public {
        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);
        module.pause();
    }

    function testRevert_Unpause_OnlyGuardian() public {
        vm.prank(pauser);
        module.pause();

        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);
        module.unpause();
    }

    function testRevert_Deposit_WhenPaused() public {
        vm.prank(pauser);
        module.pause();

        vm.expectRevert("Pausable: paused");
        vm.prank(address(metaVault));
        module.deposit(depositor, BASE);
    }
    // #endregion pause/unpause tests

    // #region initializePosition tests
    function test_InitializePosition() public {
        // Give module some balance
        deal(WETH, address(module), 1e18);
        deal(USDT, address(module), 1000e18);

        vm.prank(address(metaVault));
        module.initializePosition("");

        assertTrue(module.notFirstDeposit());
    }

    function test_InitializePosition_NoBalance() public {
        vm.prank(address(metaVault));
        module.initializePosition("");

        assertFalse(module.notFirstDeposit());
    }

    function testRevert_InitializePosition_OnlyMetaVault() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );
        module.initializePosition("");
    }
    // #endregion initializePosition tests

    // #region approve tests
    function test_Approve() public {
        address spender = PANCAKE_V3_NFT_MANAGER;
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDT;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1e18;
        amounts[1] = 1000e18;

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogApproval(
            spender, tokens, amounts
        );

        vm.prank(owner);
        module.approve(spender, tokens, amounts);

        assertEq(
            IERC20Metadata(WETH).allowance(address(module), spender),
            amounts[0]
        );
        assertEq(
            IERC20Metadata(USDT).allowance(address(module), spender),
            amounts[1]
        );
    }

    function testRevert_Approve_OnlyMetaVaultOwner() public {
        address spender = PANCAKE_V3_NFT_MANAGER;
        address[] memory tokens = new address[](1);
        tokens[0] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;

        vm.expectRevert(
            IPancakeSwapV3StandardModule.OnlyMetaVaultOwner.selector
        );
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_LengthsNotEqual() public {
        address spender = PANCAKE_V3_NFT_MANAGER;
        address[] memory tokens = new address[](2);
        tokens[0] = WETH;
        tokens[1] = USDT;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;

        vm.expectRevert(
            IPancakeSwapV3StandardModule.LengthsNotEqual.selector
        );
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_AddressZero() public {
        address spender = PANCAKE_V3_NFT_MANAGER;
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_NativeCoinNotAllowed() public {
        address spender = PANCAKE_V3_NFT_MANAGER;
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE_COIN;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(
            IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector
        );
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }
    // #endregion approve tests

    // #region manager fee tests
    function test_SetManagerFeePIPS() public {
        uint256 oldFee = module.managerFeePIPS();
        uint256 newFee = 2000; // 20%

        vm.expectEmit(true, true, true, true);
        emit IArrakisLPModule.LogSetManagerFeePIPS(oldFee, newFee);

        vm.prank(manager);
        module.setManagerFeePIPS(newFee);

        assertEq(module.managerFeePIPS(), newFee);
    }

    function testRevert_SetManagerFeePIPS_OnlyManager() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );
        module.setManagerFeePIPS(2000);
    }

    function testRevert_SetManagerFeePIPS_SameManagerFee() public {
        uint256 currentFee = module.managerFeePIPS();

        vm.expectRevert(IArrakisLPModule.SameManagerFee.selector);
        vm.prank(manager);
        module.setManagerFeePIPS(currentFee);
    }

    function testRevert_SetManagerFeePIPS_NewFeesGtPIPS() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.NewFeesGtPIPS.selector, PIPS + 1
            )
        );
        vm.prank(manager);
        module.setManagerFeePIPS(PIPS + 1);
    }
    // #endregion manager fee tests

    // #region cake rewards tests
    function test_ClaimManager() public {
        uint256 balanceBefore =
            IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        module.claimManager();
        uint256 balanceAfter =
            IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        // No rewards to claim in basic setup
        assertEq(balanceAfter, balanceBefore);
    }

    function testRevert_ClaimRewards_OnlyMetaVaultOwner() public {
        vm.expectRevert(
            IPancakeSwapV3StandardModule.OnlyMetaVaultOwner.selector
        );
        module.claimRewards(receiver);
    }

    function testRevert_ClaimRewards_AddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.claimRewards(address(0));
    }

    function test_SetReceiver() public {
        address newReceiver =
            vm.addr(uint256(keccak256(abi.encode("NewReceiver"))));

        // Mock the manager to be ownable
        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(owner)
        );

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogSetReceiver(
            cakeReceiver, newReceiver
        );

        vm.prank(owner);
        module.setReceiver(newReceiver);

        assertEq(module.cakeReceiver(), newReceiver);
    }

    function testRevert_SetReceiver_OnlyManagerOwner() public {
        address newReceiver =
            vm.addr(uint256(keccak256(abi.encode("NewReceiver"))));

        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(address(0x123))
        );

        vm.expectRevert(
            IPancakeSwapV3StandardModule.OnlyManagerOwner.selector
        );
        vm.prank(owner);
        module.setReceiver(newReceiver);
    }

    function testRevert_SetReceiver_AddressZero() public {
        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(owner)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.setReceiver(address(0));
    }

    function testRevert_SetReceiver_SameReceiver() public {
        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(owner)
        );

        vm.expectRevert(
            IPancakeSwapV3StandardModule.SameReceiver.selector
        );
        vm.prank(owner);
        module.setReceiver(cakeReceiver);
    }
    // #endregion cake rewards tests

    // #region validation tests
    function test_ValidateRebalance_WithinDeviation() public {
        // Set oracle price to match approximately the pool price
        // Get current pool price first to set a reasonable oracle price
        address poolAddress = module.pool();
        if (poolAddress != address(0)) {
            (uint160 sqrtPriceX96,,,,,,) =
                IUniswapV3PoolVariant(poolAddress).slot0();

            // Get actual token decimals
            uint8 token0Decimals = IERC20Metadata(WETH).decimals();

            // Calculate pool price using the same formula as validateRebalance
            uint256 poolPrice;
            if (sqrtPriceX96 <= type(uint128).max) {
                poolPrice = FullMath.mulDiv(
                    uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                    10 ** token0Decimals,
                    1 << 192 // 2^192
                );
            } else {
                poolPrice = FullMath.mulDiv(
                    FullMath.mulDiv(
                        uint256(sqrtPriceX96),
                        uint256(sqrtPriceX96),
                        1 << 64
                    ),
                    10 ** token0Decimals,
                    1 << 128
                );
            }

            // Set oracle price to exactly match pool price (0% deviation)
            oracle.setPrice0(poolPrice);
        } else {
            // If no pool exists, set a reasonable price
            oracle.setPrice0(3000e18); // Match token decimals
        }

        // This should succeed as the deviation is 0% (within acceptable limits)
        module.validateRebalance(oracle, 1000); // 10% max deviation
    }

    function test_ValidateRebalance_LargeSqrtPriceX96() public {
        // Test the case where sqrtPriceX96 > type(uint128).max
        // We'll need to mock the pool's slot0 function to return a large sqrtPriceX96

        // Create a large sqrtPriceX96 value that exceeds uint128.max
        uint160 largeSqrtPriceX96 =
            uint160(type(uint128).max) + 1_000_000_000_000_000_000; // Slightly larger than uint128.max

        // Get actual token decimals
        uint8 token0Decimals = IERC20Metadata(WETH).decimals();

        // Calculate expected pool price using the large sqrtPriceX96 branch
        uint256 expectedPoolPrice = FullMath.mulDiv(
            FullMath.mulDiv(
                uint256(largeSqrtPriceX96),
                uint256(largeSqrtPriceX96),
                1 << 64
            ),
            10 ** token0Decimals,
            1 << 128
        );

        // Set oracle price to match the calculated pool price
        oracle.setPrice0(expectedPoolPrice);

        // Mock the pool's slot0 function to return our large sqrtPriceX96
        address poolAddress = module.pool();
        vm.mockCall(
            poolAddress,
            abi.encodeWithSelector(
                IUniswapV3PoolVariant.slot0.selector
            ),
            abi.encode(
                largeSqrtPriceX96,
                int24(0),
                uint16(0),
                uint16(1),
                uint16(1),
                uint8(0),
                bool(true)
            )
        );

        // This should succeed as the oracle price matches the calculated pool price
        module.validateRebalance(oracle, 1000); // 10% max deviation

        // Clear the mock
        vm.clearMockedCalls();
    }

    function testRevert_ValidateRebalance_OverMaxDeviation() public {
        oracle.setPrice0(2000e6); // $2000 per ETH
        // Set oracle prices to simulate deviation
        oracle.setPrice1(1e18);

        vm.expectRevert(
            IPancakeSwapV3StandardModule.OverMaxDeviation.selector
        );
        module.validateRebalance(oracle, 500); // 5% max deviation
    }
    // #endregion validation tests

    // #region erc721 receiver tests
    function test_OnERC721Received() public {
        bytes4 selector =
            module.onERC721Received(address(0), address(0), 0, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }
    // #endregion erc721 receiver tests

    // #region edge case tests
    function test_Deposit_ZeroBalance() public {
        deal(WETH, depositor, INIT_0);
        deal(USDT, depositor, INIT_1);

        vm.startPrank(depositor);
        IERC20Metadata(WETH).approve(address(module), INIT_0);
        IERC20Metadata(USDT).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.prank(address(metaVault));
        (uint256 amount0, uint256 amount1) =
            module.deposit(depositor, BASE);

        assertEq(amount0, INIT_0);
        assertEq(amount1, INIT_1);
    }

    function test_ClaimManager_NoRewards() public {
        uint256 balanceBefore =
            IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        module.claimManager();
        uint256 balanceAfter =
            IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        assertEq(balanceAfter, balanceBefore);
    }
    // #endregion edge case tests

    // #region helper functions
    function _calculateTickRange(
        uint160 sqrtPriceX96,
        uint256 percentRange
    ) internal pure returns (int24 lowerTick, int24 upperTick) {
        // Get current tick
        int24 currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);

        lowerTick = currentTick - int24(uint24(percentRange * 120));
        upperTick = currentTick + int24(uint24(percentRange * 120));

        // Ensure ticks are properly spaced for fee tier (500 fee = 10 tick spacing)
        int24 tickSpacing = 10;
        lowerTick = (lowerTick / tickSpacing) * tickSpacing;
        upperTick = (upperTick / tickSpacing) * tickSpacing;
    }

    function _toArray(
        uint256 tokenId
    ) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](1);
        arr[0] = tokenId;
        return arr;
    }

    function _toArrayTwo(
        uint256 tokenId1,
        uint256 tokenId2
    ) internal pure returns (uint256[] memory) {
        uint256[] memory arr = new uint256[](2);
        arr[0] = tokenId1;
        arr[1] = tokenId2;
        return arr;
    }
    // #endregion helper functions

    // #region router swap functions.

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline
    ) external returns (uint256 amountOut) {
        // Transfer input token from caller (RouterSwapExecutor) to this contract
        IERC20Metadata(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Calculate actual output amount (adding 15% buffer to avoid slippage)
        uint256 actualAmountOut = amountOutMin + (amountOutMin * 15 / 100);
        
        // Give output tokens to the RouterSwapExecutor (msg.sender)
        deal(tokenOut, msg.sender, actualAmountOut);
        
        return actualAmountOut;
    }

    function pancakeV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external {
        // If amount0Delta > 0, we need to pay token0 (WETH) to the pool
        if (amount0Delta > 0) {
            IERC20Metadata(WETH).transfer(msg.sender, uint256(amount0Delta));
        }
        
        // If amount1Delta > 0, we need to pay token1 (USDT) to the pool
        if (amount1Delta > 0) {
            IERC20Metadata(USDT).transfer(msg.sender, uint256(amount1Delta));
        }
        
        // Negative deltas mean the pool is sending us tokens, which happens automatically
    }

    // #endregion router swap functions.
}
