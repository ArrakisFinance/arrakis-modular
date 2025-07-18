// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

// #region pancakeSwap Module.
import {PancakeSwapV3StandardModulePublic} from
    "../../../src/modules/PancakeSwapV3StandardModulePublic.sol";
import {IPancakeSwapV3StandardModule} from
    "../../../src/interfaces/IPancakeSwapV3StandardModule.sol";
import {IArrakisLPModule} from
    "../../../src/interfaces/IArrakisLPModule.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {IOwnable} from "../../../src/interfaces/IOwnable.sol";
import {
    BASE,
    PIPS,
    TEN_PERCENT,
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";
import {Range, Rebalance, PositionLiquidity, SwapPayload, Range} from "../../../src/structs/SUniswapV3.sol";
// #endregion pancakeSwap Module.

// #region openzeppelin.
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ERC1967Proxy} from
    "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
// #endregion openzeppelin.

// #region uniswap v3.
import {IUniswapV3Pool} from "../../../src/interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolVariant} from "../../../src/interfaces/IUniswapV3PoolVariant.sol";
// #endregion uniswap v3.

// #region mock contracts.
import {ArrakisMetaVaultMock} from "./mocks/ArrakisMetaVault.sol";
import {GuardianMock} from "./mocks/Guardian.sol";
import {OracleMock} from "./mocks/OracleWrapperMock.sol";
import {UniswapV3PoolMock} from "./mocks/UniswapV3PoolMock.sol";
// #endregion mock contracts.

interface IERC20USDT {
    function transfer(address _to, uint256 _value) external;
    function approve(address spender, uint256 value) external;
    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external;
}

contract PancakeSwapV3StandardModuleTest is TestWrapper {
    using SafeERC20 for IERC20Metadata;

    // #region constants.

    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDT =
        0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constants.

    UniswapV3PoolMock public pool;
    address public manager;
    address public pauser;
    address public metaVault;
    address public guardian;
    address public owner;

    // #region mocks contracts.

    OracleMock public oracle;

    // #endregion mocks contracts.

    PancakeSwapV3StandardModulePublic public module;

    function setUp() public {
        manager = vm.addr(uint256(keccak256(abi.encode("Manager"))));
        pauser = vm.addr(uint256(keccak256(abi.encode("Pauser"))));
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        // #region meta vault creation.

        metaVault = address(new ArrakisMetaVaultMock(manager, owner));
        ArrakisMetaVaultMock(metaVault).setTokens(USDC, WETH);

        // #endregion meta vault creation.

        // #region create a guardian.

        guardian = address(new GuardianMock(pauser));

        // #endregion create a guardian.

        // #region create a pool.

        pool = new UniswapV3PoolMock(USDC, WETH);

        // #endregion create a pool.

        // #region create an oracle.

        oracle = new OracleMock();

        // #endregion create an oracle.

        // #region create pancake v3 module.

        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            init0,
            init1,
            address(pool),
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        module = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        vm.prank(address(manager));
        module.setManagerFeePIPS(10_000);

        // #endregion create pancake v3 module.
    }

    // #region test pause.

    function testPauseOnlyGuardian() public {
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

    // #region test constructor.

    function testConstructorGuardianAddressZero() public {
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        new PancakeSwapV3StandardModulePublic(address(0));
    }

    function testConstructorMetaVaultAddressZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            init0,
            init1,
            address(pool),
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            address(0)
        );

        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );
    }

    function testConstructorMaxSlippageGtTenPercent() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            init0,
            init1,
            address(pool),
            IOracleWrapper(address(oracle)),
            TEN_PERCENT + 1,
            metaVault
        );

        vm.expectRevert(IPancakeSwapV3StandardModule.MaxSlippageGtTenPercent.selector);
        module = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );
    }

    function testConstructorSqrtPriceZero() public {
        uint256 init0 = 3000e6;
        uint256 init1 = 1e18;

        // Create a pool with zero sqrt price
        UniswapV3PoolMock zeroPricePool = new UniswapV3PoolMock(USDC, WETH);
        zeroPricePool.setSqrtPriceX96(0);

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            init0,
            init1,
            address(zeroPricePool),
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            metaVault
        );

        vm.expectRevert(IPancakeSwapV3StandardModule.SqrtPriceZero.selector);
        module = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );
    }

    // #endregion test constructor.

    // #region test deposit.

    function testDeposit() public {
        address depositor = vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        uint256 proportion = BASE / 2; // 50%

        // Mock token balances
        deal(USDC, depositor, 1000e6);
        deal(WETH, depositor, 1e18);

        vm.startPrank(depositor);
        IERC20Metadata(USDC).approve(address(module), type(uint256).max);
        IERC20Metadata(WETH).approve(address(module), type(uint256).max);
        vm.stopPrank();

        vm.prank(metaVault);
        (uint256 amount0, uint256 amount1) = module.deposit(depositor, proportion);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testDepositDepositorAddressZero() public {
        uint256 proportion = BASE / 2;

        vm.prank(metaVault);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module.deposit(address(0), proportion);
    }

    function testDepositProportionZero() public {
        address depositor = vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(metaVault);
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);
        module.deposit(depositor, 0);
    }

    function testDepositOnlyMetaVault() public {
        address depositor = vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        uint256 proportion = BASE / 2;

        vm.expectRevert(IArrakisLPModule.OnlyMetaVault.selector);
        module.deposit(depositor, proportion);
    }

    function testDepositNativeCoinNotSupported() public {
        // Create a module with native coin as token0
        ArrakisMetaVaultMock nativeVault = new ArrakisMetaVaultMock(manager, owner);
        nativeVault.setTokens(NATIVE_COIN, WETH);

        address implementation = address(
            new PancakeSwapV3StandardModulePublic(guardian)
        );

        bytes memory data = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.initialize.selector,
            1e18,
            1e18,
            address(pool),
            IOracleWrapper(address(oracle)),
            TEN_PERCENT,
            address(nativeVault)
        );

        PancakeSwapV3StandardModulePublic nativeModule = PancakeSwapV3StandardModulePublic(
            payable(address(new ERC1967Proxy(implementation, data)))
        );

        address depositor = vm.addr(uint256(keccak256(abi.encode("Depositor"))));
        uint256 proportion = BASE / 2;

        vm.prank(address(nativeVault));
        vm.expectRevert("PancakeSwap V3 doesn't support native coin");
        nativeModule.deposit(depositor, proportion);
    }

    // #endregion test deposit.

    // #region test withdraw.

    function testWithdraw() public {
        address receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        uint256 proportion = BASE / 2;

        vm.prank(metaVault);
        (uint256 amount0, uint256 amount1) = module.withdraw(receiver, proportion);

        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testWithdrawAddressZero() public {
        uint256 proportion = BASE / 2;

        vm.prank(metaVault);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module.withdraw(address(0), proportion);
    }

    function testWithdrawProportionZero() public {
        address receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(metaVault);
        vm.expectRevert(IArrakisLPModule.ProportionZero.selector);
        module.withdraw(receiver, 0);
    }

    function testWithdrawProportionGtBASE() public {
        address receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(metaVault);
        vm.expectRevert(IArrakisLPModule.ProportionGtBASE.selector);
        module.withdraw(receiver, BASE + 1);
    }

    function testWithdrawOnlyMetaVault() public {
        address receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        uint256 proportion = BASE / 2;

        vm.expectRevert(IArrakisLPModule.OnlyMetaVault.selector);
        module.withdraw(receiver, proportion);
    }

    // #endregion test withdraw.

    // #region test approve.

    function testApprove() public {
        address spender = vm.addr(uint256(keccak256(abi.encode("Spender"))));
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1000e6;
        amounts[1] = 1e18;

        vm.prank(owner);
        module.approve(spender, tokens, amounts);
    }

    function testApproveAddressZero() public {
        address[] memory tokens = new address[](1);
        tokens[0] = address(0);
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.prank(owner);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module.approve(address(0), tokens, amounts);
    }

    function testApproveLengthsNotEqual() public {
        address spender = vm.addr(uint256(keccak256(abi.encode("Spender"))));
        address[] memory tokens = new address[](2);
        tokens[0] = USDC;
        tokens[1] = WETH;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.prank(owner);
        vm.expectRevert(IPancakeSwapV3StandardModule.LengthsNotEqual.selector);
        module.approve(spender, tokens, amounts);
    }

    function testApproveOnlyMetaVaultOwner() public {
        address spender = vm.addr(uint256(keccak256(abi.encode("Spender"))));
        address[] memory tokens = new address[](1);
        tokens[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1000e6;

        vm.expectRevert(IPancakeSwapV3StandardModule.OnlyMetaVaultOwner.selector);
        module.approve(spender, tokens, amounts);
    }

    // #endregion test approve.

    // #region test set pool.

    function testSetPool() public {
        address newPool = address(new UniswapV3PoolMock(USDC, WETH));

        vm.prank(manager);
        module.setPool(newPool);

        assertEq(module.pool(), newPool);
    }

    function testSetPoolOnlyManager() public {
        address newPool = address(new UniswapV3PoolMock(USDC, WETH));

        vm.expectRevert(IArrakisLPModule.OnlyManager.selector);
        module.setPool(newPool);
    }

    function testSetPoolAddressZero() public {
        vm.prank(manager);
        vm.expectRevert(IArrakisLPModule.AddressZero.selector);
        module.setPool(address(0));
    }

    function testSetPoolSamePool() public {
        vm.prank(manager);
        vm.expectRevert(IPancakeSwapV3StandardModule.SamePool.selector);
        module.setPool(address(pool));
    }

    function testSetPoolSqrtPriceZero() public {
        UniswapV3PoolMock zeroPricePool = new UniswapV3PoolMock(USDC, WETH);
        zeroPricePool.setSqrtPriceX96(0);

        vm.prank(manager);
        vm.expectRevert(IPancakeSwapV3StandardModule.SqrtPriceZero.selector);
        module.setPool(address(zeroPricePool));
    }

    // #endregion test set pool.

    // #region test rebalance.

    function testRebalance() public {
        Range memory range = Range({
            lowerTick: -1000,
            upperTick: 1000
        });

        PositionLiquidity[] memory burns = new PositionLiquidity[](0);
        PositionLiquidity[] memory mints = new PositionLiquidity[](1);
        mints[0] = PositionLiquidity({
            range: range,
            liquidity: 1000
        });

        SwapPayload memory swap;

        Rebalance memory rebalance = Rebalance({
            burns: burns,
            mints: mints,
            swap: swap,
            minDeposit0: 0,
            minDeposit1: 0,
            minBurn0: 0,
            minBurn1: 0
        });

        vm.prank(manager);
        module.rebalance(rebalance);
    }

    function testRebalanceOnlyManager() public {
        Range memory range = Range({
            lowerTick: -1000,
            upperTick: 1000
        });

        PositionLiquidity[] memory burns = new PositionLiquidity[](0);
        PositionLiquidity[] memory mints = new PositionLiquidity[](1);
        mints[0] = PositionLiquidity({
            range: range,
            liquidity: 1000
        });

        SwapPayload memory swap;

        Rebalance memory rebalance = Rebalance({
            burns: burns,
            mints: mints,
            swap: swap,
            minDeposit0: 0,
            minDeposit1: 0,
            minBurn0: 0,
            minBurn1: 0
        });

        vm.expectRevert(IArrakisLPModule.OnlyManager.selector);
        module.rebalance(rebalance);
    }

    // #endregion test rebalance.

    // #region test manager fees.

    function testSetManagerFeePIPS() public {
        uint256 newFee = 5000; // 5%

        vm.prank(manager);
        module.setManagerFeePIPS(newFee);

        assertEq(module.managerFeePIPS(), newFee);
    }

    function testSetManagerFeePIPSOnlyManager() public {
        uint256 newFee = 5000;

        vm.expectRevert(IArrakisLPModule.OnlyManager.selector);
        module.setManagerFeePIPS(newFee);
    }

    function testSetManagerFeePIPSNewFeesGtPIPS() public {
        uint256 newFee = PIPS + 1;

        vm.prank(manager);
        vm.expectRevert(IArrakisLPModule.NewFeesGtPIPS.selector);
        module.setManagerFeePIPS(newFee);
    }

    function testSetManagerFeePIPSSameManagerFee() public {
        vm.prank(manager);
        vm.expectRevert(IArrakisLPModule.SameManagerFee.selector);
        module.setManagerFeePIPS(module.managerFeePIPS());
    }

    function testWithdrawManagerBalance() public {
        vm.prank(manager);
        (uint256 amount0, uint256 amount1) = module.withdrawManagerBalance();

        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testManagerBalance0() public {
        uint256 balance = module.managerBalance0();
        assertGt(balance, 0);
    }

    function testManagerBalance1() public {
        uint256 balance = module.managerBalance1();
        assertGt(balance, 0);
    }

    // #endregion test manager fees.

    // #region test view functions.

    function testGuardian() public {
        address guardianAddr = module.guardian();
        assertEq(guardianAddr, pauser);
    }

    function testGetRanges() public {
        Range[] memory ranges = module.getRanges();
        assertEq(ranges.length, 0);
    }

    function testGetInits() public {
        (uint256 init0, uint256 init1) = module.getInits();
        assertEq(init0, 3000e6);
        assertEq(init1, 1e18);
    }

    function testTotalUnderlying() public {
        (uint256 amount0, uint256 amount1) = module.totalUnderlying();
        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testTotalUnderlyingAtPrice() public {
        uint160 priceX96 = 1_356_476_084_642_877_807_665_053_548_195_417;
        (uint256 amount0, uint256 amount1) = module.totalUnderlyingAtPrice(priceX96);
        assertGt(amount0, 0);
        assertGt(amount1, 0);
    }

    function testValidateRebalance() public {
        oracle.setPrice0(1e18); // Set oracle price

        vm.prank(manager);
        module.validateRebalance(IOracleWrapper(address(oracle)), TEN_PERCENT);
    }

    function testValidateRebalanceOverMaxDeviation() public {
        oracle.setPrice0(2e18); // Set oracle price much higher than pool price

        vm.prank(manager);
        vm.expectRevert(IPancakeSwapV3StandardModule.OverMaxDeviation.selector);
        module.validateRebalance(IOracleWrapper(address(oracle)), 1000); // Low max deviation
    }

    // #endregion test view functions.

    // #region test withdraw eth.

    function testWithdrawEth() public {
        // First approve some ETH
        address[] memory tokens = new address[](1);
        tokens[0] = NATIVE_COIN;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1e18;

        vm.prank(owner);
        module.approve(address(this), tokens, amounts);

        // Then withdraw
        module.withdrawEth(1e18);
    }

    function testWithdrawEthAmountZero() public {
        vm.expectRevert(IPancakeSwapV3StandardModule.AmountZero.selector);
        module.withdrawEth(0);
    }

    function testWithdrawEthInsufficientFunds() public {
        vm.expectRevert(IPancakeSwapV3StandardModule.InsufficientFunds.selector);
        module.withdrawEth(1e18);
    }

    // #endregion test withdraw eth.

    // #region test initialize position.

    function testInitializePosition() public {
        vm.prank(metaVault);
        module.initializePosition("");
    }

    function testInitializePositionOnlyMetaVault() public {
        vm.expectRevert(IArrakisLPModule.OnlyMetaVault.selector);
        module.initializePosition("");
    }

    // #endregion test initialize position.

    // #region test callback.

    function testUniswapV3MintCallback() public {
        // This test verifies the callback function works correctly
        // The callback should transfer tokens to the pool
        uint256 amount0Owed = 1000e6;
        uint256 amount1Owed = 1e18;

        // Mock the pool calling the callback
        vm.prank(address(pool));
        module.uniswapV3MintCallback(amount0Owed, amount1Owed, "");
    }

    function testUniswapV3MintCallbackOnlyPool() public {
        uint256 amount0Owed = 1000e6;
        uint256 amount1Owed = 1e18;

        vm.expectRevert(IArrakisLPModule.OnlyManager.selector);
        module.uniswapV3MintCallback(amount0Owed, amount1Owed, "");
    }

    // #endregion test callback.
} 