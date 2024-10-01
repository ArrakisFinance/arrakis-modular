// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.

import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";

// #endregion foundry.

// #region openzeppelin.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// #endregion openzeppelin.

import {
    BunkerModule,
    IBunkerModule,
    IArrakisLPModule,
    IOracleWrapper
} from "../../../src/modules/BunkerModule.sol";

// #region constants.
import {
    BASE,
    TEN_PERCENT,
    PIPS
} from "../../../src/constants/CArrakis.sol";
// #endregion constants.

// #region mocks.

import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {GuardianMock} from "./mocks/GuardianMock.sol";

// #endregion mocks.

contract BunkerModuleTest is TestWrapper {
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    BunkerModule public module;
    ArrakisMetaVaultMock public metaVault;
    address public manager;
    GuardianMock public guardian;
    address public pauser;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create guardian.

        guardian = new GuardianMock();
        guardian.setPauser(pauser);

        // #endregion create guardian.

        // #region create meta vault.

        metaVault = new ArrakisMetaVaultMock();
        metaVault.setToken0AndToken1(USDC, WETH);

        // #endregion create meta vault.

        // #region create bunker module.

        address implementation =
            address(new BunkerModule(address(guardian)));

        bytes memory data = abi.encodeWithSelector(
            IBunkerModule.initialize.selector, address(metaVault)
        );

        module = BunkerModule(
            address(new ERC1967Proxy(implementation, data))
        );

        // #endregion create bunker module.
    }

    // #region test constructor.

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module = new BunkerModule(address(0));
    }

    // #endregion test constructor.

    // #region test initialize.

    function testInitializeMetaVaultAddressZero() public {
        address implementation =
            address(new BunkerModule(address(guardian)));

        module = BunkerModule(
            address(new ERC1967Proxy(implementation, ""))
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.initialize(address(0));
    }

    // #endregion test initialize.

    // #region test initialize position.

    function testInitializePositionNotImplemented() public {
        // Initialize position should not revert.
        module.initializePosition("");
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

    // #region test withdraw.

    function testWithdrawOnlyMetaVault() public {
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

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
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

        address receiver = address(0);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.withdraw(receiver, BASE);
    }

    function testWithdrawProportionZero() public {
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);

        module.withdraw(receiver, 0);
    }

    function testWithdrawProportionGtBASE() public {
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);

        module.withdraw(receiver, BASE + 1);
    }

    function testWithdrawAmountsZeros() public {
        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        vm.expectRevert(IBunkerModule.AmountsZeros.selector);

        module.withdraw(receiver, BASE);
    }

    function testWithdraw() public {
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        module.withdraw(receiver, BASE);

        assertEq(IERC20(WETH).balanceOf(receiver), 1 ether);
        assertEq(IERC20(USDC).balanceOf(receiver), 2_500_000_000);
    }

    function testWithdrawBis() public {
        deal(USDC, address(module), 2_500_000_000);

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        module.withdraw(receiver, BASE);

        assertEq(IERC20(WETH).balanceOf(receiver), 0);
        assertEq(IERC20(USDC).balanceOf(receiver), 2_500_000_000);
    }

    function testWithdrawBis2() public {
        deal(WETH, address(module), 1 ether);

        address receiver = vm.addr(20);

        vm.prank(address(metaVault));

        module.withdraw(receiver, BASE);

        assertEq(IERC20(WETH).balanceOf(receiver), 1 ether);
    }

    // #endregion test withdraw.

    // #region test validate rebalance.

    function testValidateNotImplemented() public {
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.validateRebalance(
            IOracleWrapper(address(0)), TEN_PERCENT
        );
    }

    // #endregion test validate rebalance.

    // #region test withdraw manager balance.

    function testWithdrawManagerBalanceNotImplemented() public {
        (uint256 amount0, uint256 amount1) =
            module.withdrawManagerBalance();

        assertEq(amount0, 0);
        assertEq(amount1, 0);
    }

    // #endregion test withdraw manager balance.

    // #region test set manager fee pips.

    function testSetManagerFeePIPSNotImplemented() public {
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.setManagerFeePIPS(PIPS);
    }

    // #endregion test set manager fee pips.

    // #region test manager fee pips.

    function testManagerFeePIPS() public {
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.managerFeePIPS();
    }

    // #region test manager balance 0 and manager balance 1.

    function testGetManagerBalances() public {
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.managerBalance0();
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.managerBalance1();
    }

    // #endregion test manager balance 0 and manager balance 1.

    // #region test get inits.

    function testGetInits() public {
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.getInits();
    }

    // #endregion test get inits.
    // #region total underlying.

    function testTotalUnderlying() public {
        deal(WETH, address(module), 1 ether);
        deal(USDC, address(module), 2_500_000_000);

        (uint256 amount0, uint256 amount1) = module.totalUnderlying();

        assertEq(amount1, 1 ether);
        assertEq(amount0, 2_500_000_000);
    }

    // #endregion total underlying.

    // #region total underlying at price.

    function testTotalUnderlyingAtPriceNotImplemented() public {
        uint160 priceX96 = 1e18;
        vm.expectRevert(IBunkerModule.NotImplemented.selector);
        module.totalUnderlyingAtPrice(priceX96);
    }

    // #endregion total underlying price.
}
