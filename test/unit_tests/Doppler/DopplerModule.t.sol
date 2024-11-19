// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region uniswap.
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {LPFeeLibrary} from
    "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SqrtPriceMath} from
    "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
// #endregion uniswap.

import {DopplerData} from "../../../src/structs/SDoppler.sol";
import {DopplerModule} from "../../../src/modules/DopplerModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";

// #region openzeppelin.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #endregion openzeppelin.

// #region mocks.
import {
    DopplerDeployerMock,
    DopplerMock
} from "./mocks/DopplerDeployerMock.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {MetaVault} from "./mocks/MetaVault.sol";
// #endregion mocks.

contract DopplerModuleTest is TestWrapper {
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    PoolManager public poolManager;
    DopplerDeployerMock public dopplerDeployer;
    DopplerModule public dopplerModule;
    address public guardian;
    address public pauser;
    address public metaVault;
    bytes32 public constant salt = bytes32(0);

    function setUp() public {
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create poolManager.
        poolManager = new PoolManager();
        // #endregion create poolManager.

        // #region create dopplerDeployer.
        dopplerDeployer = new DopplerDeployerMock();
        // #endregion create dopplerDeployer.

        // #region create guardian.
        guardian = address(new GuardianMock(pauser));
        // #endregion create guardian.

        // #region create dopplerModule.
        dopplerModule = new DopplerModule(
            address(poolManager), guardian, address(dopplerDeployer)
        );
        // #endregion create dopplerModule.
    }

    // #region constructor test.

    function test_constructor_poolManager_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        dopplerModule = new DopplerModule(
            address(0), guardian, address(dopplerDeployer)
        );
    }

    function test_constructor_guardian_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        dopplerModule = new DopplerModule(
            address(poolManager), address(0), address(dopplerDeployer)
        );
    }

    function test_constructor_dopplerDeployer_address_zero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        dopplerModule = new DopplerModule(
            address(poolManager), guardian, address(0)
        );
    }

    // #endregion constructor test.

    // #region initialize test.

    function test_initialize_metavault_address_zero() public {
        DopplerData memory dopplerData;
        bool isInversed;
        uint24 fee;
        int24 tickSpacing;
        uint160 sqrtPriceX96;

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        dopplerModule.initialize(
            dopplerData,
            isInversed,
            address(0),
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    function test_initialize_fee_too_high() public {
        DopplerData memory dopplerData;
        bool isInversed;
        metaVault =
            vm.addr(uint256(keccak256(abi.encode("MetaVault"))));
        uint24 fee = LPFeeLibrary.MAX_LP_FEE + 1;
        int24 tickSpacing;
        uint160 sqrtPriceX96;

        vm.expectRevert(
            abi.encodeWithSelector(
                LPFeeLibrary.LPFeeTooLarge.selector, fee
            )
        );
        dopplerModule.initialize(
            dopplerData,
            isInversed,
            metaVault,
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    function test_initialize_invalid_tickspacing() public {
        DopplerData memory dopplerData;
        bool isInversed;
        metaVault =
            vm.addr(uint256(keccak256(abi.encode("MetaVault"))));
        uint24 fee;
        int24 tickSpacing = TickMath.MIN_TICK_SPACING - 1;
        uint160 sqrtPriceX96;

        vm.expectRevert(
            abi.encodeWithSelector(
                TickMath.InvalidTick.selector, tickSpacing
            )
        );
        dopplerModule.initialize(
            dopplerData,
            isInversed,
            metaVault,
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    function test_initialize_invalid_price() public {
        DopplerData memory dopplerData;
        bool isInversed;
        metaVault =
            vm.addr(uint256(keccak256(abi.encode("MetaVault"))));
        uint24 fee;
        int24 tickSpacing = TickMath.MIN_TICK_SPACING + 1;
        uint160 sqrtPriceX96;

        vm.expectRevert(SqrtPriceMath.InvalidPrice.selector);
        dopplerModule.initialize(
            dopplerData,
            isInversed,
            metaVault,
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    function test_initialize() public {
        DopplerData memory dopplerData;
        bool isInversed;
        metaVault = address(new MetaVault(USDC, WETH));
        uint24 fee;
        int24 tickSpacing = TickMath.MIN_TICK_SPACING + 1;
        uint160 sqrtPriceX96 = TickMath.MIN_SQRT_PRICE + 1;

        dopplerModule.initialize(
            dopplerData,
            isInversed,
            metaVault,
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    // #endregion initialize test.

    // #region fund test.

    function initializeDopplerModule() public {
        DopplerData memory dopplerData;
        bool isInversed;
        metaVault = address(new MetaVault(USDC, WETH));
        uint24 fee;
        int24 tickSpacing = TickMath.MIN_TICK_SPACING + 1;
        uint160 sqrtPriceX96 = TickMath.MIN_SQRT_PRICE + 1;

        dopplerModule.initialize(
            dopplerData,
            isInversed,
            metaVault,
            fee,
            tickSpacing,
            sqrtPriceX96,
            salt
        );
    }

    function test_fund_only_metaVault() public {
        initializeDopplerModule();
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                metaVault
            )
        );
        dopplerModule.fund(address(0), 0, 0);
    }

    function test_fund_depositor_address_zero() public {
        initializeDopplerModule();
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(metaVault);
        dopplerModule.fund(address(0), 0, 0);
    }

    function test_fund() public {
        initializeDopplerModule();

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        vm.prank(metaVault);
        dopplerModule.fund(depositor, 0, 0);
    }

    // #endregion fund test.

    // #region withdraw test.

    function fund() public {
        initializeDopplerModule();

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        vm.prank(metaVault);
        dopplerModule.fund(depositor, 0, 0);
    }

    function test_withdraw_only_metaVault() public {
        fund();
        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisLPModule.OnlyMetaVault.selector,
                address(this),
                metaVault
            )
        );
        dopplerModule.withdraw(address(0), 0);
    }

    function test_withdraw_receiver_address_zero() public {
        fund();
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        vm.prank(metaVault);
        dopplerModule.withdraw(address(0), 0);
    }

    function test_withdraw() public {
        fund();

        // #region mock migrate.

        address doppler = address(dopplerModule.doppler());

        DopplerMock(doppler).setTokens(USDC, WETH);
        DopplerMock(doppler).setAmounts(100, 200);

        deal(USDC, doppler, 100);
        deal(WETH, doppler, 200);

        // #region mock migrate.

        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        assertEq(IERC20(USDC).balanceOf(receiver), 0);
        assertEq(IERC20(WETH).balanceOf(receiver), 0);

        vm.prank(metaVault);
        dopplerModule.withdraw(receiver, 0);

        assertEq(IERC20(USDC).balanceOf(receiver), 100);
        assertEq(IERC20(WETH).balanceOf(receiver), 200);
    }

    // #endregion withdraw test.
}
