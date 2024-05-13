// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.
// #region Valantis Module.
import {ValantisModulePublic} from
    "../../../src/modules/ValantisHOTModulePublic.sol";
import {IValantisHOTModule} from
    "../../../src/interfaces/IValantisHOTModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
// #endregion Valantis Module.

// #region openzeppelin.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// #endregion openzeppelin.

// #region constants.
import {
    BASE,
    PIPS,
    TEN_PERCENT
} from "../../../src/constants/CArrakis.sol";
// #endregion constants.

// #region mocks.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {SovereignPoolMock} from "./mocks/SovereignPoolMock.sol";
import {SovereignALMMock} from "./mocks/SovereignALMMock.sol";
import {SovereignALMBuggyMock} from
    "./mocks/SovereignALMBuggyMock.sol";
import {SovereignALMBuggy2Mock} from
    "./mocks/SovereignALMBuggy2Mock.sol";
import {SovereignALMBuggy3Mock} from
    "./mocks/SovereignALMBuggy3Mock.sol";
import {SovereignALMBuggy4Mock} from
    "./mocks/SovereignALMBuggy4Mock.sol";
import {SovereignALMBuggy5Mock} from
    "./mocks/SovereignALMBuggy5Mock.sol";
import {SovereignALMBuggy6Mock} from
    "./mocks/SovereignALMBuggy6Mock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";
import {GuardianMock} from "./mocks/GuardianMock.sol";

// #endregion mocks.

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ValantisHOTModuleTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 public constant INIT0 = 2000e6;
    uint256 public constant INIT1 = 1e18;
    uint24 public constant MAX_SLIPPAGE = TEN_PERCENT;

    // #endregion constant properties.

    ValantisModulePublic public module;
    address public implementation;
    ArrakisMetaVaultMock public metaVault;
    address public manager;
    SovereignPoolMock public sovereignPool;
    SovereignALMMock public sovereignALM;
    OracleMock public oracle;
    GuardianMock public guardian;
    address public owner;
    address public pauser;

    uint160 public expectedSqrtSpotPriceUpperX96;
    uint160 public expectedSqrtSpotPriceLowerX96;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create oracle.

        oracle = new OracleMock();

        uint256 price0 = oracle.getPrice0();
        uint256 uPrice0 = FullMath.mulDiv(price0, 10_100, 10_000);
        uint256 lPrice0 = FullMath.mulDiv(price0, 9900, 10_000);

        expectedSqrtSpotPriceUpperX96 = SafeCast.toUint160(
            FullMath.mulDiv(
                Math.sqrt(uPrice0), 2 ** 96, Math.sqrt(1e6)
            )
        );
        expectedSqrtSpotPriceLowerX96 = SafeCast.toUint160(
            FullMath.mulDiv(
                Math.sqrt(lPrice0), 2 ** 96, Math.sqrt(1e6)
            )
        );

        // #endregion create oracle.

        // #region create guardian.

        guardian = new GuardianMock();
        guardian.setPauser(pauser);

        // #endregion create guardian.

        // #region create meta vault.

        metaVault = new ArrakisMetaVaultMock();
        metaVault.setManager(manager);
        metaVault.setToken0AndToken1(USDC, WETH);
        metaVault.setOwner(owner);

        // #endregion create meta vault.

        sovereignPool = new SovereignPoolMock();
        sovereignPool.setToken0AndToken1(USDC, WETH);

        // #region create sovereign ALM.

        sovereignALM = new SovereignALMMock();
        sovereignALM.setToken0AndToken1(USDC, WETH);

        // #endregion create sovereign ALM.

        // #region create valantis module.

        implementation =
            address(new ValantisModulePublic(address(guardian)));

        bytes memory data = abi.encodeWithSelector(
            IValantisHOTModule.initialize.selector,
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, data))
        );

        vm.prank(owner);
        module.setALMAndManagerFees(
            address(sovereignALM), address(oracle)
        );

        // #endregion create valantis module.
    }

    // #region test constructor.

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new ValantisModulePublic(address(0));
    }

    // #endregion test constructor.

    // #region test initialize.

    function testInitializeSovereignPoolAddressZero() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(0), INIT0, INIT1, MAX_SLIPPAGE, address(metaVault)
        );
    }

    function testInitializeSovereignALMAddressZero() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.setALMAndManagerFees(address(0), address(oracle));
    }

    function testInitializeOracleAddressZero() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(owner);
        module.setALMAndManagerFees(address(sovereignALM), address(0));
    }

    function testsetALMAndManagerFeesALMAlreadySet() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        vm.prank(owner);
        module.setALMAndManagerFees(
            address(sovereignALM), address(oracle)
        );

        vm.expectRevert(IValantisHOTModule.ALMAlreadySet.selector);
        vm.prank(owner);
        module.setALMAndManagerFees(
            address(sovereignALM), address(oracle)
        );
    }

    function testsetALMAndManagerFeesOnlyMetaVaultOwner() public {
        address notVaultOwner =
            vm.addr(uint256(keccak256(abi.encode("Not Vault Owner"))));
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        vm.expectRevert(
            IValantisHOTModule.OnlyMetaVaultOwner.selector
        );
        vm.prank(notVaultOwner);
        module.setALMAndManagerFees(
            address(sovereignALM), address(oracle)
        );
    }

    function testInitializeInitsAreZeros() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        vm.expectRevert(IArrakisLPModule.InitsAreZeros.selector);

        module.initialize(
            address(sovereignPool),
            0,
            0,
            MAX_SLIPPAGE,
            address(metaVault)
        );
    }

    function testInitializeSlippageBiggerThanTenPercent() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        vm.expectRevert(
            IValantisHOTModule.MaxSlippageGtTenPercent.selector
        );

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            TEN_PERCENT * 2,
            address(metaVault)
        );
    }

    function testInitialize() public {
        assertEq(address(module.metaVault()), address(metaVault));
        assertEq(address(module.pool()), address(sovereignPool));
        assertEq(address(module.alm()), address(sovereignALM));
        (uint256 init0, uint256 init1) = module.getInits();
        assertEq(init0, INIT0);
        assertEq(init1, INIT1);
        assertEq(module.maxSlippage(), MAX_SLIPPAGE);
        assertEq(address(module.guardian()), pauser);
    }

    function testInitializeMetaVaultAddressZero() public {
        implementation =
            address(new ValantisModulePublic(address(guardian)));

        module = ValantisModulePublic(
            address(new ERC1967Proxy(implementation, ""))
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(0)
        );
    }

    // #endregion test initialize.

    // #region test initialize position.

    function testInitializePositionOnlyMetaVault() public {
        uint256 amount0 = 3000e6;

        deal(USDC, address(module), amount0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                metaVault
            )
        );
        module.initializePosition();
    }

    function testInitializePositionOnlyToken0() public {
        uint256 amount0 = 3000e6;

        deal(USDC, address(module), amount0);

        vm.prank(address(metaVault));
        module.initializePosition();
    }

    function testInitializePositionOnlyToken1() public {
        uint256 amount1 = 1e18;

        deal(WETH, address(module), amount1);

        vm.prank(address(metaVault));
        module.initializePosition();
    }

    // #endregion test initialize position.

    // #region test pause.

    function testPauserOnlyGuardian() public {
        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);

        module.pause();
    }

    function testPauser() public {
        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);
    }

    // #endregion test pause.

    // #region test unpause.

    function testUnPauseOnlyGuardian() public {
        // #region pause first.

        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);

        // #endregion pause first.

        vm.expectRevert(IArrakisLPModule.OnlyGuardian.selector);

        module.unpause();
    }

    function testUnPause() public {
        // #region pause first.

        assertEq(module.paused(), false);

        vm.prank(pauser);

        module.pause();

        assertEq(module.paused(), true);

        // #endregion pause first.

        vm.prank(pauser);

        module.unpause();

        assertEq(module.paused(), false);
    }

    // #endregion test unpause.

    // #region test deposit.

    function testDepositOnlyMetaVault() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        deal(address(metaVault), 1 ether);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.deposit{value: 1 ether}(depositor, proportion);
    }

    function testDepositMsgValueNotZero() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        deal(address(metaVault), 1 ether);

        vm.prank(address(metaVault));
        vm.expectRevert(IValantisHOTModule.NoNativeToken.selector);

        module.deposit{value: 1 ether}(depositor, proportion);
    }

    function testDepositDepositorAddressZero() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.deposit(address(0), proportion);
    }

    function testDepositProportionZero() public {
        address depositor = vm.addr(10);
        uint256 proportion = 0;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        module.deposit(depositor, proportion);
    }

    function testDepositInitsWithExtraTokenOnALM() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        deal(USDC, address(sovereignALM), expectedAmount0 / 2);
        deal(WETH, address(sovereignALM), expectedAmount1 / 2);

        sovereignPool.setReserves(
            expectedAmount0 / 2, expectedAmount1 / 2
        );

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        assertEq(
            IERC20(USDC).balanceOf(address(sovereignALM)),
            expectedAmount0
        );
        assertEq(
            IERC20(WETH).balanceOf(address(sovereignALM)),
            expectedAmount1
        );

        assertEq(
            IERC20(USDC).balanceOf(address(manager)),
            expectedAmount0 / 2
        );
        assertEq(
            IERC20(WETH).balanceOf(address(manager)),
            expectedAmount1 / 2
        );
    }

    function testDepositInitsWithExtraTokenOnALMTwo() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        deal(USDC, address(sovereignALM), expectedAmount0 / 2);

        sovereignPool.setReserves(expectedAmount0 / 2, 0);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        assertEq(
            IERC20(USDC).balanceOf(address(sovereignALM)),
            expectedAmount0
        );
        assertEq(
            IERC20(WETH).balanceOf(address(sovereignALM)),
            expectedAmount1
        );

        assertEq(
            IERC20(USDC).balanceOf(address(manager)),
            expectedAmount0 / 2
        );
    }

    function testDepositInitsWithExtraTokenOnALMThree() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        deal(WETH, address(sovereignALM), expectedAmount1 / 2);

        sovereignPool.setReserves(0, expectedAmount1 / 2);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        assertEq(
            IERC20(USDC).balanceOf(address(sovereignALM)),
            expectedAmount0
        );
        assertEq(
            IERC20(WETH).balanceOf(address(sovereignALM)),
            expectedAmount1
        );

        assertEq(
            IERC20(WETH).balanceOf(address(manager)),
            expectedAmount1 / 2
        );
    }

    function testDeposit() public {
        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        assertEq(
            IERC20(USDC).balanceOf(address(sovereignALM)),
            expectedAmount0
        );
        assertEq(
            IERC20(WETH).balanceOf(address(sovereignALM)),
            expectedAmount1
        );
    }

    // #endregion test deposit.

    // #region test withdraw.

    function testWithdrawOnlyMetaVault() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        // #endregion deposit.

        address receiver = vm.addr(20);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                address(metaVault)
            )
        );

        module.withdraw(receiver, BASE);
    }

    function testWithdrawReceiverAddressZero() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        // #endregion deposit.

        address receiver = address(0);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.withdraw(receiver, BASE);
    }

    function testWithdrawProportionZero() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        // #endregion deposit.

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        module.withdraw(receiver, 0);
    }

    function testWithdrawProportionGtBASE() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        // #endregion deposit.

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);

        module.withdraw(receiver, BASE + 1);
    }

    function testWithdrawAmountsZeros() public {
        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IValantisHOTModule.AmountsZeros.selector);

        module.withdraw(receiver, BASE);
    }

    function testWithdraw() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = BASE / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.deposit(depositor, proportion);

        // #endregion deposit.

        address receiver = vm.addr(20);
        sovereignPool.setReserves(expectedAmount0, expectedAmount1);
        vm.prank(address(metaVault));

        module.withdraw(receiver, BASE);

        assertEq(IERC20(USDC).balanceOf(receiver), expectedAmount0);
        assertEq(IERC20(WETH).balanceOf(receiver), expectedAmount1);
    }

    // #endregion test withdraw.

    // #region test swap.

    function testSwapOnlyManager() public {
        bool zeroForOne = false;
        uint256 expectedMinReturn = 1230e6;
        uint256 amountIn = 0.5 ether;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapExpectedMinReturnTooLow() public {
        bool zeroForOne = false;
        uint256 expectedMinReturn = 1230e6;
        uint256 amountIn = 0.7 ether;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        vm.expectRevert(
            IValantisHOTModule.ExpectedMinReturnTooLow.selector
        );
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapExpectedMinReturnTooLow2() public {
        bool zeroForOne = true;
        uint256 expectedMinReturn = 0.1 ether;
        uint256 amountIn = 1230e6;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        vm.expectRevert(
            IValantisHOTModule.ExpectedMinReturnTooLow.selector
        );
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapNotEnoughToken0() public {
        bool zeroForOne = true;
        uint256 expectedMinReturn = 0.6 ether;
        uint256 amountIn = 1250e6;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        deal(USDC, address(sovereignALM), amountIn / 2);

        vm.expectRevert(IValantisHOTModule.NotEnoughToken0.selector);
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapNotEnoughToken1() public {
        bool zeroForOne = false;
        uint256 expectedMinReturn = 1250e6;
        uint256 amountIn = 0.6 ether;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        deal(WETH, address(sovereignALM), amountIn / 2);

        vm.expectRevert(IValantisHOTModule.NotEnoughToken1.selector);
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapCallFailed() public {
        bool zeroForOne = false;
        uint256 expectedMinReturn = 1250e6;
        uint256 amountIn = 0.6 ether;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.failedSwap.selector);

        sovereignPool.setReserves(0, amountIn);
        deal(WETH, address(sovereignALM), amountIn);

        vm.expectRevert(IValantisHOTModule.SwapCallFailed.selector);
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapZeroForOneSlippageTooHigh() public {
        bool zeroForOne = true;
        uint256 expectedMinReturn = 0.6 ether;
        uint256 amountIn = 1250e6;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap.selector);

        sovereignPool.setReserves(amountIn, 0);
        deal(USDC, address(sovereignALM), amountIn);

        vm.expectRevert(IValantisHOTModule.SlippageTooHigh.selector);
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwapOneForZeroSlippageTooHigh() public {
        bool zeroForOne = false;
        uint256 expectedMinReturn = 1250e6;
        uint256 amountIn = 0.6 ether;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap1.selector);

        sovereignPool.setReserves(0, amountIn);
        deal(WETH, address(sovereignALM), amountIn);

        vm.expectRevert(IValantisHOTModule.SlippageTooHigh.selector);
        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    function testSwap() public {
        bool zeroForOne = true;
        uint256 expectedMinReturn = 0.6 ether;
        uint256 amountIn = 1250e6;
        address router = address(this);
        bytes memory payload =
            abi.encodeWithSelector(this.swap3.selector);

        sovereignPool.setReserves(amountIn, 0);
        deal(USDC, address(sovereignALM), amountIn);

        vm.prank(manager);
        module.swap(
            zeroForOne,
            expectedMinReturn,
            amountIn,
            router,
            expectedSqrtSpotPriceUpperX96,
            expectedSqrtSpotPriceLowerX96,
            payload
        );
    }

    // #endregion test swap.

    // #region test setPriceBounds.

    function testSetPriceBoundsOnlyManager() public {
        uint160 sqrtPriceLowX96 = TickMath.getSqrtRatioAtTick(10);
        uint160 sqrtPriceHighX96 = TickMath.getSqrtRatioAtTick(10);

        uint160 expectedSqrtSpotPriceUpperX96 =
            TickMath.getSqrtRatioAtTick(31);
        uint160 expectedSqrtSpotPriceLowerX96 =
            TickMath.getSqrtRatioAtTick(30);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        module.setPriceBounds(
            sqrtPriceLowX96,
            sqrtPriceHighX96,
            expectedSqrtSpotPriceLowerX96,
            expectedSqrtSpotPriceUpperX96
        );
    }

    function testSetPriceBounds() public {
        uint160 sqrtPriceLowX96 = TickMath.getSqrtRatioAtTick(10);
        uint160 sqrtPriceHighX96 = TickMath.getSqrtRatioAtTick(10);

        uint160 expectedSqrtSpotPriceUpperX96 =
            TickMath.getSqrtRatioAtTick(31);
        uint160 expectedSqrtSpotPriceLowerX96 =
            TickMath.getSqrtRatioAtTick(30);

        vm.prank(manager);

        module.setPriceBounds(
            sqrtPriceLowX96,
            sqrtPriceHighX96,
            expectedSqrtSpotPriceLowerX96,
            expectedSqrtSpotPriceUpperX96
        );
    }

    // #endregion test setPriceBounds.

    // #region test validate rebalance.

    function testValidatedRebalanceOverMaxDeviation() public {
        uint256 price0 = oracle.getPrice0();

        price0 = FullMath.mulDiv(price0, 88, 100);

        uint160 sqrtSpotPriceX96 = SafeCast.toUint160(
            FullMath.mulDiv(
                Math.sqrt(price0), 2 ** 96, Math.sqrt(1e6)
            )
        );
        // #region set amm sqrtSpotPriceX96.

        sovereignALM.setSqrtSpotPriceX96(
            SafeCast.toUint160(sqrtSpotPriceX96)
        );

        // #endregion set amm sqrtSpotPriceX96.

        vm.expectRevert(IValantisHOTModule.OverMaxDeviation.selector);
        module.validateRebalance(oracle, TEN_PERCENT);
    }

    function testValidatedRebalanceOverMaxDeviation2() public {
        // #region set amm sqrtSpotPriceX96.

        sovereignALM.setSqrtSpotPriceX96(type(uint160).max - 1);

        // #endregion set amm sqrtSpotPriceX96.

        vm.expectRevert(IValantisHOTModule.OverMaxDeviation.selector);
        module.validateRebalance(oracle, TEN_PERCENT);
    }

    function testValidatedRebalance() public {
        uint256 price0 = oracle.getPrice0();

        price0 = FullMath.mulDiv(price0, 95, 100);

        uint160 sqrtSpotPriceX96 = SafeCast.toUint160(
            FullMath.mulDiv(
                Math.sqrt(price0), 2 ** 96, Math.sqrt(1e6)
            )
        );
        // #region set amm sqrtSpotPriceX96.

        sovereignALM.setSqrtSpotPriceX96(
            SafeCast.toUint160(sqrtSpotPriceX96)
        );

        // #endregion set amm sqrtSpotPriceX96.

        module.validateRebalance(oracle, TEN_PERCENT);
    }

    // #endregion test validate rebalance.

    // #region test withdraw manager balances.

    function testWithdrawManagerBalance() public {
        deal(USDC, address(sovereignPool), 2000e6);
        deal(WETH, address(sovereignPool), 1e18);

        sovereignPool.setManagesFees(2000e6, 1e18);

        assertEq(
            IERC20(USDC).balanceOf(address(sovereignPool)), 2000e6
        );
        assertEq(IERC20(WETH).balanceOf(address(sovereignPool)), 1e18);

        assertEq(IERC20(USDC).balanceOf(manager), 0);
        assertEq(IERC20(WETH).balanceOf(manager), 0);

        module.withdrawManagerBalance();

        assertEq(IERC20(USDC).balanceOf(manager), 2000e6);
        assertEq(IERC20(WETH).balanceOf(manager), 1e18);

        assertEq(IERC20(USDC).balanceOf(address(sovereignPool)), 0);
        assertEq(IERC20(WETH).balanceOf(address(sovereignPool)), 0);
    }

    // #endregion test withdraw manager balances.

    // #region test set manager fee bips.

    function testSetManagerFeePIPSNotManager() public {
        /// @dev no fees assign.
        assertEq(sovereignPool.poolManagerFeeBips(), 0);

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyManager.selector,
                address(this),
                manager
            )
        );

        module.setManagerFeePIPS(PIPS);
    }

    function testSetManagerFeePIPSGtPIPS() public {
        /// @dev no fees assign.
        assertEq(sovereignPool.poolManagerFeeBips(), 0);

        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.NewFeesGtPIPS.selector, PIPS + 1
            )
        );
        module.setManagerFeePIPS(PIPS + 1);
    }

    function testSetManagerFeePIPS() public {
        /// @dev no fees assign.
        assertEq(sovereignPool.poolManagerFeeBips(), 0);

        vm.prank(manager);

        module.setManagerFeePIPS(PIPS);

        assertEq(sovereignPool.poolManagerFeeBips(), 10_000);
    }

    // #endregion test set manager fee bips.

    // #region test manager balance 0 and manager balance 1.

    function testGetManagerBalances() public {
        deal(USDC, address(sovereignPool), 2000e6);
        deal(WETH, address(sovereignPool), 1e18);

        sovereignPool.setManagesFees(2000e6, 1e18);

        assertEq(module.managerBalance0(), 2000e6);
        assertEq(module.managerBalance1(), 1e18);
    }

    // #endregion test manager balance 0 and manager balance 1.

    // #region test set manager fee PIPS.

    function testManagerFeePIPS() public {
        /// @dev no fees assign.
        assertEq(module.managerFeePIPS(), 0);

        vm.prank(address(manager));

        module.setManagerFeePIPS(PIPS);

        assertEq(sovereignPool.poolManagerFeeBips(), 10_000);
        assertEq(module.managerFeePIPS(), PIPS);
    }

    // #endregion test manager fee PIPS.

    // #region test get inits.

    function testGetInits() public {
        (uint256 init0, uint256 init1) = module.getInits();

        assertEq(init0, 2000e6);
        assertEq(init1, 1e18);
    }

    // #endregion test get inits.

    // #region total underlying.

    function testTotalUnderlying() public {
        sovereignPool.setReserves(2000e6, 1e18);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        assertEq(amount0, 2000e6);
        assertEq(amount1, 1e18);
    }

    // #endregion total underlying.

    // #region total underlying at price.

    function testTotalUnderlyingAtPrice() public {
        deal(USDC, address(sovereignALM), 2000e6);
        deal(WETH, address(sovereignALM), 1e18);

        uint160 priceX96 = 1e18;

        (uint256 amount0, uint256 amount1) =
            module.totalUnderlyingAtPrice(priceX96);

        assertEq(amount0, 2000e6);
        assertEq(amount1, 1e18);
    }

    // #endregion total underlying price.

    // #region mocks functions.

    function swap() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 1250e6);
        deal(WETH, msg.sender, 0.59 ether);
    }

    function swap1() external {
        IERC20(WETH).transferFrom(
            msg.sender, address(this), 0.6 ether
        );
        deal(USDC, msg.sender, 1000e6);
    }

    function swap2() external {
        IERC20(WETH).transferFrom(
            msg.sender, address(this), 0.6 ether
        );
        deal(USDC, msg.sender, 1250e6);
    }

    function swap3() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 1250e6);
        deal(WETH, msg.sender, 0.6 ether);
    }

    function failedSwap() external {
        revert("something wrong happen!");
    }

    // #endregion mocks functions.
}
