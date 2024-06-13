// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.
// #region Valantis Module.
import {ValantisModulePrivate} from
    "../../../src/modules/ValantisHOTModulePrivate.sol";
import {IValantisHOTModule} from
    "../../../src/interfaces/IValantisHOTModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePrivate} from
    "../../../src/interfaces/IArrakisLPModulePrivate.sol";
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
    TEN_PERCENT
} from "../../../src/constants/CArrakis.sol";
// #endregion constants.

// #region mocks.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVaultMock.sol";
import {SovereignPoolMock} from "./mocks/SovereignPoolMock.sol";
import {SovereignALMMock} from "./mocks/SovereignALMMock.sol";
import {SovereignALMBuggy1Mock} from
    "./mocks/SovereignALMBuggy1Mock.sol";
import {SovereignALMBuggy2Mock} from
    "./mocks/SovereignALMBuggy2Mock.sol";
import {SovereignALMMock} from "./mocks/SovereignALMMock.sol";
import {OracleMock} from "./mocks/OracleMock.sol";
import {GuardianMock} from "./mocks/GuardianMock.sol";

// #endregion mocks.

import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ValantisHOTModulePrivateTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 public constant INIT0 = 2000e6;
    uint256 public constant INIT1 = 1e18;
    uint24 public constant MAX_SLIPPAGE = TEN_PERCENT;

    // #endregion constant properties.

    ValantisModulePrivate public module;
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
            FullMath.mulDiv(Math.sqrt(uPrice0), 2 ** 96, 1)
        );
        expectedSqrtSpotPriceLowerX96 = SafeCast.toUint160(
            FullMath.mulDiv(Math.sqrt(lPrice0), 2 ** 96, 1)
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

        address implementation =
            address(new ValantisModulePrivate(address(guardian)));

        bytes memory data = abi.encodeWithSelector(
            IValantisHOTModule.initialize.selector,
            address(sovereignPool),
            INIT0,
            INIT1,
            MAX_SLIPPAGE,
            address(metaVault)
        );

        module = ValantisModulePrivate(
            address(new ERC1967Proxy(implementation, data))
        );

        vm.prank(manager);
        module.setManagerFeePIPS(TEN_PERCENT / 10);

        vm.prank(owner);
        module.setALMAndManagerFees(
            address(sovereignALM), address(oracle)
        );

        // #endregion create valantis module.
    }

    // #region test fund.

    function testFundOnlyMetaVault() public {
        address depositor = vm.addr(10);

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

        module.fund{value: 1 ether}(
            depositor, expectedAmount0, expectedAmount1
        );
    }

    function testFundMsgValueNotZero() public {
        address depositor = vm.addr(10);

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        deal(address(metaVault), 1 ether);

        vm.prank(address(metaVault));
        vm.expectRevert(IValantisHOTModule.NoNativeToken.selector);

        module.fund{value: 1 ether}(
            depositor, expectedAmount0, expectedAmount1
        );
    }

    function testFundDepositorAddressZero() public {
        address depositor = vm.addr(10);

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        IERC20(USDC).approve(address(module), expectedAmount0);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);

        module.fund(address(0), expectedAmount0, expectedAmount1);
    }

    function testFundAmountsZero() public {
        address depositor = vm.addr(10);

        uint256 expectedAmount0 = 0;
        uint256 expectedAmount1 = 0;

        vm.prank(address(metaVault));
        vm.expectRevert(IArrakisLPModulePrivate.DepositZero.selector);

        module.fund(depositor, expectedAmount0, expectedAmount1);
    }

    function testFund() public {
        address depositor = vm.addr(10);

        uint256 expectedAmount0 = 2000e6 / 2;
        uint256 expectedAmount1 = 1e18 / 2;

        deal(USDC, depositor, expectedAmount0);
        deal(WETH, depositor, expectedAmount1);

        vm.prank(depositor);
        IERC20(USDC).approve(address(module), expectedAmount0);
        vm.prank(depositor);
        IERC20(WETH).approve(address(module), expectedAmount1);

        vm.prank(address(metaVault));

        module.fund(depositor, expectedAmount0, expectedAmount1);

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
}
