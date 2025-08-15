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
import {RebalanceParams, MintReturnValues} from "../../../src/structs/SPancakeSwapV3.sol";
import {ModifyPosition, SwapPayload} from "../../../src/structs/SUniswapV3.sol";
// #endregion module imports

// #region openzeppelin imports
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// #endregion openzeppelin imports

// #region pancakeswap imports
import {INonfungiblePositionManagerPancake} from
    "../../../src/interfaces/INonfungiblePositionManagerPancake.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
// #endregion pancakeswap imports

// #region mock imports
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleWrapperMock} from "./mocks/OracleWrapperMock.sol";
import {PancakeFactoryMock} from "./mocks/PancakeFactoryMock.sol";
import {SimplePancakePoolMock} from "./mocks/SimplePancakePoolMock.sol";
import {PancakePositionManagerMock} from "./mocks/PancakePositionManagerMock.sol";
import {MasterChefV3Mock} from "./mocks/MasterChefV3Mock.sol";
import {RouterMock} from "./mocks/RouterMock.sol";
// #endregion mock imports

contract PancakeSwapV3StandardModulePublicTest is TestWrapper {
    // #region constants
    address public constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address public constant WETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address public constant CAKE = 0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82;
    uint24 public constant POOL_FEE = 3000;
    uint256 public constant INIT_0 = 1e18; // USDC
    uint256 public constant INIT_1 = 3000e18;   // WETH
    uint24 public constant MAX_SLIPPAGE = 1000; // 10%
    // #endregion constants

    // #region state variables
    PancakeSwapV3StandardModulePublic public module;
    ArrakisMetaVaultMock public metaVault;
    GuardianMock public guardian;
    OracleWrapperMock public oracle;
    PancakeFactoryMock public factory;
    SimplePancakePoolMock public pool;
    PancakePositionManagerMock public nftPositionManager;
    MasterChefV3Mock public masterChefV3;
    RouterMock public router;

    address public manager;
    address public pauser;
    address public owner;
    address public cakeReceiver;
    address public depositor;
    address public receiver;
    // #endregion state variables

    // #region setup
    function setUp() public {
        _reset(vm.envString("BSC_RPC_URL"), 57670269);

        // Setup addresses
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        cakeReceiver = vm.addr(uint256(keccak256(abi.encode("CakeReceiver"))));
        depositor = vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // Deploy mock contracts
        metaVault = new ArrakisMetaVaultMock(manager, owner);
        metaVault.setTokens(USDC, WETH);

        guardian = new GuardianMock(pauser);
        oracle = new OracleWrapperMock();
        factory = new PancakeFactoryMock();
        pool = new SimplePancakePoolMock(USDC, WETH, POOL_FEE);
        nftPositionManager = new PancakePositionManagerMock();
        masterChefV3 = new MasterChefV3Mock();
        router = new RouterMock();

        // Set up pool in factory
        factory.setPool(USDC, WETH, POOL_FEE, address(pool));

        // Deploy module
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                address(nftPositionManager),
                address(factory),
                CAKE,
                address(masterChefV3)
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
        deal(USDC, depositor, 100000e6);
        deal(WETH, depositor, 100e18);
        deal(CAKE, address(masterChefV3), 1000e18);
    }
    // #endregion setup

    // #region deployment tests
    function test_Constructor() public {
        assertEq(module.nftPositionManager(), address(nftPositionManager));
        assertEq(module.factory(), address(factory));
        assertEq(module.CAKE(), CAKE);
        assertEq(module.masterChefV3(), address(masterChefV3));
    }

    function test_Initialize() public {
        assertEq(address(module.oracle()), address(oracle));
        assertEq(module.maxSlippage(), MAX_SLIPPAGE);
        assertEq(module.cakeReceiver(), cakeReceiver);
        assertEq(module.pool(), address(pool));
        assertEq(address(module.metaVault()), address(metaVault));
        assertEq(address(module.token0()), USDC);
        assertEq(address(module.token1()), WETH);

        (uint256 init0, uint256 init1) = module.getInits();
        assertEq(init0, INIT_0);
        assertEq(init1, INIT_1);
    }

    function testRevert_Initialize_AddressZero() public {
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                address(nftPositionManager),
                address(factory),
                CAKE,
                address(masterChefV3)
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
                address(nftPositionManager),
                address(factory),
                CAKE,
                address(masterChefV3)
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

        vm.expectRevert(IPancakeSwapV3StandardModule.MaxSlippageGtTenPercent.selector);
        new ERC1967Proxy(implementation, data);
    }

    function testRevert_Initialize_InitsAreZeros() public {
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                address(nftPositionManager),
                address(factory),
                CAKE,
                address(masterChefV3)
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

    function testRevert_Initialize_PoolNotFound() public {
        PancakeFactoryMock emptyFactory = new PancakeFactoryMock();
        
        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                address(nftPositionManager),
                address(emptyFactory),
                CAKE,
                address(masterChefV3)
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

        vm.expectRevert(IPancakeSwapV3StandardModule.PoolNotFound.selector);
        new ERC1967Proxy(implementation, data);
    }

    function testRevert_Initialize_NativeCoinNotAllowed() public {
        ArrakisMetaVaultMock nativeVault = new ArrakisMetaVaultMock(manager, owner);
        nativeVault.setTokens(NATIVE_COIN, WETH);

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(
                address(guardian),
                address(nftPositionManager),
                address(factory),
                CAKE,
                address(masterChefV3)
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

        vm.expectRevert(IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector);
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
        uint160 priceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        (uint256 amount0, uint256 amount1) = module.totalUnderlyingAtPrice(priceX96);
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
        deal(USDC, depositor, INIT_0);
        deal(WETH, depositor, INIT_1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), INIT_0);
        IERC20Metadata(WETH).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.expectEmit(true, true, true, true);
        emit IArrakisLPModulePublic.LogDeposit(depositor, BASE, INIT_0, INIT_1);

        vm.prank(address(metaVault));
        (uint256 amount0, uint256 amount1) = module.deposit(depositor, BASE);

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
        
        vm.expectRevert(IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector);
        vm.prank(address(metaVault));
        module.deposit{value: 1 ether}(depositor, BASE);
    }

    function test_Deposit_SubsequentDeposits() public {
        deal(USDC, depositor, INIT_0);
        deal(WETH, depositor, INIT_1);

        // First deposit
        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), INIT_0);
        IERC20Metadata(WETH).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.prank(address(metaVault));
        module.deposit(depositor, BASE);

        deal(USDC, depositor, 2000e18);
        deal(WETH, depositor, 2e18);

        // Second deposit with proportion
        uint256 proportion = BASE / 2; // 50%
        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), 2000e18);
        IERC20Metadata(WETH).approve(address(module), 2e18);
        vm.stopPrank();

        vm.prank(address(metaVault));
        module.deposit(depositor, proportion);
    }
    // #endregion deposit tests

    // #region withdraw tests  
    // function test_Withdraw() public {
    //     // Setup position first
    //     _setupPosition();

    //     uint256 balanceBefore0 = IERC20Metadata(USDC).balanceOf(receiver);
    //     uint256 balanceBefore1 = IERC20Metadata(WETH).balanceOf(receiver);

    //     vm.prank(address(metaVault));
    //     (uint256 amount0, uint256 amount1) = module.withdraw(receiver, BASE / 2);

    //     uint256 balanceAfter0 = IERC20Metadata(USDC).balanceOf(receiver);
    //     uint256 balanceAfter1 = IERC20Metadata(WETH).balanceOf(receiver);

    //     assertGt(balanceAfter0, balanceBefore0);
    //     assertGt(balanceAfter1, balanceBefore1);
    //     assertTrue(module.notFirstDeposit()); // Should still be true for partial withdrawal
    // }

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
        deal(USDC, address(module), 1000e6);
        deal(WETH, address(module), 1e18);

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
        address spender = address(router);
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e6;
        amounts[1] = 1e18;

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogApproval(spender, tokens, amounts);

        vm.prank(owner);
        module.approve(spender, tokens, amounts);

        assertEq(IERC20Metadata(USDC).allowance(address(module), spender), amounts[0]);
        assertEq(IERC20Metadata(WETH).allowance(address(module), spender), amounts[1]);
    }

    function testRevert_Approve_OnlyMetaVaultOwner() public {
        address spender = address(router);
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IPancakeSwapV3StandardModule.OnlyMetaVaultOwner.selector);
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_LengthsNotEqual() public {
        address spender = address(router);
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IPancakeSwapV3StandardModule.LengthsNotEqual.selector);
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_AddressZero() public {
        address spender = address(router);
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }

    function testRevert_Approve_NativeCoinNotAllowed() public {
        address spender = address(router);
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE_COIN;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IPancakeSwapV3StandardModule.NativeCoinNotAllowed.selector);
        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }
    // #endregion approve tests

    // #region rebalance tests
    function test_Rebalance_Mint() public {
        _setupPosition();

        // Prepare mint params
        INonfungiblePositionManagerPancake.MintParams[] memory mintParams = 
            new INonfungiblePositionManagerPancake.MintParams[](1);
        mintParams[0] = INonfungiblePositionManagerPancake.MintParams({
            token0: USDC,
            token1: WETH,
            fee: POOL_FEE,
            tickLower: -60,
            tickUpper: 60,
            amount0Desired: 1000e6,
            amount1Desired: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: block.timestamp
        });

        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                amountIn: 0,
                router: address(0),
                payload: "",
                zeroForOne: false,
                expectedMinReturn: 0
            }),
            mintParams: mintParams,
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 900e6,
            minDeposit1: 0.9e18
        });

        // Fund module for minting
        deal(USDC, address(module), 2000e6);
        deal(WETH, address(module), 2e18);

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogRebalance(0, 0, 1000e6, 1e18);

        vm.prank(manager);
        module.rebalance(params);

        uint256[] memory tokenIds = module.tokenIds();
        assertEq(tokenIds.length, 2);
    }

    function testRevert_Rebalance_OnlyManager() public {
        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                amountIn: 0,
                router: address(0),
                payload: "",
                zeroForOne: false,
                expectedMinReturn: 0
            }),
            mintParams: new INonfungiblePositionManagerPancake.MintParams[](0),
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 0,
            minDeposit1: 0
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );
        module.rebalance(params);
    }

    function testRevert_Rebalance_MintToken0() public {
        INonfungiblePositionManagerPancake.MintParams[] memory mintParams = 
            new INonfungiblePositionManagerPancake.MintParams[](1);
        mintParams[0] = INonfungiblePositionManagerPancake.MintParams({
            token0: USDC,
            token1: WETH,
            fee: POOL_FEE,
            tickLower: -60,
            tickUpper: 60,
            amount0Desired: 100e6,
            amount1Desired: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: block.timestamp
        });

        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                amountIn: 0,
                router: address(0),
                payload: "",
                zeroForOne: false,
                expectedMinReturn: 0
            }),
            mintParams: mintParams,
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 1000e6, // Too high minimum
            minDeposit1: 0
        });

        deal(USDC, address(module), 200e6);
        deal(WETH, address(module), 2e18);

        vm.expectRevert(IPancakeSwapV3StandardModule.MintToken0.selector);
        vm.prank(manager);
        module.rebalance(params);
    }

    function testRevert_Rebalance_WrongRouter() public {
        SwapPayload memory swapPayload = SwapPayload({
            amountIn: 1000e6,
            router: address(metaVault), // Wrong router
            payload: "",
            zeroForOne: true,
            expectedMinReturn: 0.9e18
        });

        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: swapPayload,
            mintParams: new INonfungiblePositionManagerPancake.MintParams[](0),
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 0,
            minDeposit1: 0
        });

        vm.expectRevert(IPancakeSwapV3StandardModule.WrongRouter.selector);
        vm.prank(manager);
        module.rebalance(params);
    }
    // #endregion rebalance tests

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
                IArrakisLPModule.NewFeesGtPIPS.selector,
                PIPS + 1
            )
        );
        vm.prank(manager);
        module.setManagerFeePIPS(PIPS + 1);
    }
    // #endregion manager fee tests

    // #region cake rewards tests
    function test_ClaimManager() public {
        _setupPositionWithCakeRewards();

        uint256 balanceBefore = IERC20Metadata(CAKE).balanceOf(cakeReceiver);

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogManagerClaim(cakeReceiver, 1e17);

        module.claimManager();

        uint256 balanceAfter = IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        assertGt(balanceAfter, balanceBefore);
    }

    function test_ClaimRewards() public {
        _setupPositionWithCakeRewards();

        uint256 balanceBefore = IERC20Metadata(CAKE).balanceOf(receiver);

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogClaim(receiver, 100e18 - 1e17);

        vm.prank(owner);
        module.claimRewards(receiver);

        uint256 balanceAfter = IERC20Metadata(CAKE).balanceOf(receiver);
        assertGt(balanceAfter, balanceBefore);
    }

    function testRevert_ClaimRewards_OnlyMetaVaultOwner() public {
        vm.expectRevert(IPancakeSwapV3StandardModule.OnlyMetaVaultOwner.selector);
        module.claimRewards(receiver);
    }

    function testRevert_ClaimRewards_AddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.claimRewards(address(0));
    }

    function test_SetReceiver() public {
        address newReceiver = vm.addr(uint256(keccak256(abi.encode("NewReceiver"))));
        
        // Mock the manager to be ownable
        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(owner)
        );

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogSetReceiver(cakeReceiver, newReceiver);

        vm.prank(owner);
        module.setReceiver(newReceiver);

        assertEq(module.cakeReceiver(), newReceiver);
    }

    function testRevert_SetReceiver_OnlyManagerOwner() public {
        address newReceiver = vm.addr(uint256(keccak256(abi.encode("NewReceiver"))));
        
        vm.mockCall(
            manager,
            abi.encodeWithSelector(IOwnable.owner.selector),
            abi.encode(address(0x123))
        );

        vm.expectRevert(IPancakeSwapV3StandardModule.OnlyManagerOwner.selector);
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

        vm.expectRevert(IPancakeSwapV3StandardModule.SameReceiver.selector);
        vm.prank(owner);
        module.setReceiver(cakeReceiver);
    }
    // #endregion cake rewards tests

    // #region validation tests
    function testRevert_ValidateRebalance_OverMaxDeviation() public {
        oracle.setPrice0(2000e18); // $2000 per ETH  
        pool.setSqrtPriceX96(158113883008419000000000000000); // much higher price

        vm.expectRevert(IPancakeSwapV3StandardModule.OverMaxDeviation.selector);
        module.validateRebalance(oracle, 500); // 5% max deviation
    }
    // #endregion validation tests

    // #region erc721 receiver tests
    function test_OnERC721Received() public {
        bytes4 selector = module.onERC721Received(address(0), address(0), 0, "");
        assertEq(selector, IERC721Receiver.onERC721Received.selector);
    }
    // #endregion erc721 receiver tests

    // #region edge case tests
    function test_Deposit_ZeroBalance() public {
        deal(USDC, depositor, INIT_0);
        deal(WETH, depositor, INIT_1);

        // #region allowance.

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), INIT_0);
        IERC20Metadata(WETH).approve(address(module), INIT_1);
        vm.stopPrank();

        // #endregion allowance.

        vm.prank(address(metaVault));
        (uint256 amount0, uint256 amount1) = module.deposit(depositor, BASE);
        
        assertEq(amount0, INIT_0);
        assertEq(amount1, INIT_1);
    }

    function test_ClaimManager_NoRewards() public {
        uint256 balanceBefore = IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        module.claimManager();
        uint256 balanceAfter = IERC20Metadata(CAKE).balanceOf(cakeReceiver);
        assertEq(balanceAfter, balanceBefore);
    }
    // #endregion edge case tests

    // #region helper functions
    function _setupPosition() internal {
        deal(USDC, depositor, INIT_0);
        deal(WETH, depositor, INIT_1);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), INIT_0);
        IERC20Metadata(WETH).approve(address(module), INIT_1);
        vm.stopPrank();

        vm.prank(address(metaVault));
        module.deposit(depositor, BASE);

        // #region mint and rebalance.

        // Prepare mint params
        INonfungiblePositionManagerPancake.MintParams[] memory mintParams = 
            new INonfungiblePositionManagerPancake.MintParams[](1);
        mintParams[0] = INonfungiblePositionManagerPancake.MintParams({
            token0: USDC,
            token1: WETH,
            fee: POOL_FEE,
            tickLower: -60,
            tickUpper: 60,
            amount0Desired: 1000e6,
            amount1Desired: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(module),
            deadline: block.timestamp
        });

        RebalanceParams memory params = RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                amountIn: 0,
                router: address(0),
                payload: "",
                zeroForOne: false,
                expectedMinReturn: 0
            }),
            mintParams: mintParams,
            minBurn0: 0,
            minBurn1: 0,
            minDeposit0: 900e6,
            minDeposit1: 0.9e18
        });

        // Fund module for minting
        deal(USDC, address(module), 2000e6);
        deal(WETH, address(module), 2e18);

        vm.expectEmit(true, true, true, true);
        emit IPancakeSwapV3StandardModule.LogRebalance(0, 0, 1000e6, 1e18);

        vm.prank(manager);
        module.rebalance(params);

        // #endregion mint and rebalance.
    }

    function _setupPositionWithFees() internal {
        _setupPosition();
        uint256[] memory tokenIds = module.tokenIds();
        if (tokenIds.length > 0) {
            // Add some mock fees to the position
            nftPositionManager.addFeesToPosition(tokenIds[0], 100e6, 0.1e18);
        }
    }

    function _setupPositionWithCakeRewards() internal {
        _setupPosition();
        uint256[] memory tokenIds = module.tokenIds();
        if (tokenIds.length > 0) {
            // Set some CAKE rewards
            masterChefV3.setCakeReward(tokenIds[0], 100e18);
            deal(CAKE, address(module), 100e18);
        }
    }
    // #endregion helper functions
}