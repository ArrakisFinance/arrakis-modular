// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.
// #region Valantis Module.
import {ValantisModule} from "../../../src/modules/ValantisSOTModule.sol";
import {IValantisSOTModule} from "../../../src/interfaces/IValantisSOTModule.sol";
import {IArrakisLPModule} from "../../../src/interfaces/IArrakisLPModule.sol";
// #endregion Valantis Module.

// #region openzeppelin.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// #endregion openzeppelin.

// #region constants.
import {PIPS, TEN_PERCENT} from "../../../src/constants/CArrakis.sol";
// #endregion constants.

// #region mocks.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {SovereignPoolMock} from "./mocks/SovereignPoolMock.sol";
import {SovereignALMMock} from "./mocks/SovereignALMMock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";
import {GuardianMock} from "./mocks/GuardianMock.sol";

// #endregion mocks.

contract ValantisSOTModuleTest is TestWrapper {
    // #region constant properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 public constant INIT0 = 2000e6;
    uint256 public constant INIT1 = 1e18;
    uint24 public constant MAX_SLIPPAGE = TEN_PERCENT;

    // #endregion constant properties.

    ValantisModule public module;
    ArrakisMetaVaultMock public metaVault;
    address public manager;
    SovereignPoolMock public sovereignPool;
    SovereignALMMock public sovereignALM;
    OracleMock public oracle;
    GuardianMock public guardian;
    address public owner;
    address public pauser;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create oracle.

        oracle = new OracleMock();

        // #endregion create oracle.

        // #region create guardian.

        guardian = new GuardianMock();
        guardian.setPauser(pauser);

        // #endregion create guardian.

        // #region create meta vault.

        metaVault = new ArrakisMetaVaultMock();
        metaVault.setManager(manager);
        metaVault.setToken0AndToken1(USDC, WETH);

        // #endregion create meta vault.

        sovereignPool = new SovereignPoolMock();
        sovereignPool.setToken0AndToken1(USDC, WETH);

        // #region create sovereign ALM.

        sovereignALM = new SovereignALMMock();
        sovereignALM.setToken0AndToken1(USDC, WETH);

        // #endregion create sovereign ALM.

        // #region create valantis module.

        module = new ValantisModule();
        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(sovereignALM),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(oracle),
            address(guardian)
        );

        // #endregion create valantis module.
    }

    // #region test constructor.

    function testConstructorMetaVaultAddressZero() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(0),
            address(sovereignPool),
            address(sovereignALM),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(oracle),
            address(guardian)
        );
    }

    function testConstructorSovereignPoolAddressZero() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(metaVault),
            address(0),
            address(sovereignALM),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(oracle),
            address(guardian)
        );
    }

    function testConstructorSovereignALMAddressZero() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(0),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(oracle),
            address(guardian)
        );
    }

    function testConstructorInitsAreZeros() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.InitsAreZeros.selector);

        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(sovereignALM),
            0,
            0,
            MAX_SLIPPAGE,
            address(oracle),
            address(guardian)
        );
    }

    function testConstructorSlippageBiggerThanTenPercent() public {
        module = new ValantisModule();

        vm.expectRevert(IValantisSOTModule.MaxSlippageGtTenPercent.selector);

        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(sovereignALM),
            INIT0,
            INIT1,
            TEN_PERCENT * 2,
            address(oracle),
            address(guardian)
        );
    }

    function testConstructorOracleAddressZero() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(sovereignALM),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(0),
            address(guardian)
        );
    }

    function testConstructorGuardianAddressZero() public {
        module = new ValantisModule();

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(
            address(metaVault),
            address(sovereignPool),
            address(sovereignALM),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(oracle),
            address(0)
        );
    }

    function testConstructor() public {
        assertEq(address(module.metaVault()), address(metaVault));
        assertEq(address(module.pool()), address(sovereignPool));
        assertEq(address(module.alm()), address(sovereignALM));
        (uint256 init0, uint256 init1) = module.getInits();
        assertEq(init0, INIT0);
        assertEq(init1, INIT1);
        assertEq(module.maxSlippage(), MAX_SLIPPAGE);
        assertEq(address(module.oracle()), address(oracle));
        assertEq(address(module.guardian()), pauser);
    }

    // #endregion test constructor.

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
        uint256 proportion = PIPS / 2;

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
        uint256 proportion = PIPS / 2;

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        deal(address(metaVault), 1 ether);

        vm.prank(address(metaVault));
        vm.expectRevert(IValantisSOTModule.NoNativeToken.selector);

        module.deposit{value: 1 ether}(depositor, proportion);
    }

    function testDepositDepositorAddressZero() public {
        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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

    function testDeposit() public {
        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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
        uint256 proportion = PIPS / 2;

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

        module.withdraw(receiver, PIPS);
    }

    function testWithdrawReceiverAddressZero() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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

        module.withdraw(receiver, PIPS);
    }

    function testWithdrawProportionZero() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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

    function testWithdrawProportionGtPIPS() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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

        vm.expectRevert(IArrakisLPModule.ProportionGtPIPS.selector);

        module.withdraw(receiver, PIPS + 1);
    }

    function testWithdrawTotalSupplyZero() public {
        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IValantisSOTModule.TotalSupplyZero.selector);

        module.withdraw(receiver, PIPS);
    }

    function testWithdraw() public {
        // #region deposit.

        address depositor = vm.addr(10);
        uint256 proportion = PIPS / 2;

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

        module.withdraw(receiver, PIPS);

        assertEq(IERC20(USDC).balanceOf(receiver), expectedAmount0);
        assertEq(IERC20(WETH).balanceOf(receiver), expectedAmount1);
    }

    // #endregion test withdraw.

    // #region test withdraw manager balances.

    function testWithdrawManagerBalance() public {
        deal(USDC, address(sovereignPool), 2000e6);
        deal(WETH, address(sovereignPool), 1e18);

        sovereignPool.setManagesFees(2000e6, 1e18);

        assertEq(IERC20(USDC).balanceOf(address(sovereignPool)), 2000e6);
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
        deal(USDC, address(sovereignALM), 2000e6);
        deal(WETH, address(sovereignALM), 1e18);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        assertEq(amount0, 2000e6);
        assertEq(amount1, 1e18);
    }

    // #endregion total underlying.
}
