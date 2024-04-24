// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPrivateVaultRouter} from
    "../../../src/interfaces/IArrakisPrivateVaultRouter.sol";
import {
    IPermit2,
    SignatureTransferDetails
} from "../../../src/interfaces/IPermit2.sol";
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";
import {ArrakisPrivateVaultRouter} from
    "../../../src/ArrakisPrivateVaultRouter.sol";
import {PrivateRouterSwapExecutor} from
    "../../../src/PrivateRouterSwapExecutor.sol";
import {
    AddLiquidityData,
    SwapAndAddData,
    SwapData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data
} from "../../../src/structs/SPrivateRouter.sol";
import {
    PermitBatchTransferFrom,
    PermitTransferFrom,
    TokenPermissions
} from "../../../src/structs/SPermit2.sol";
import {
    NATIVE_COIN
} from "../../../src/constants/CArrakis.sol";

// #region openzeppelin.
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// #endregion openzeppelin.

// #region solady.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady.

// #region mocks.
import {ArrakisPrivateVaultMock} from
    "./mocks/ArrakisPrivateVaultMock.sol";
import {ArrakisPrivateVaultMockBuggy} from
    "./mocks/ArrakisPrivateVaultMockBuggy.sol";
import {ArrakisPrivateVaultMockBuggy2} from
    "./mocks/ArrakisPrivateVaultMockBuggy2.sol";
import {ArrakisPublicVaultMock} from
    "./mocks/ArrakisPublicVaultMock.sol";
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactoryMock.sol";
// #endregion mocks.

contract ArrakisPrivateVaultRouterTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // #endregion constant properties.

    // #region public properties.

    ArrakisPrivateVaultRouter public router;
    PrivateRouterSwapExecutor public swapExecutor;
    address public owner;

    // #endregion public properties.

    // #region mocks.

    ArrakisMetaVaultFactoryMock public factory;

    // #endregion mocks.

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));

        // #region factory mock.

        factory = new ArrakisMetaVaultFactoryMock();

        // #endregion factory mock.

        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );

        swapExecutor = new PrivateRouterSwapExecutor(
            address(router), NATIVE_COIN
        );

        vm.prank(owner);
        router.updateSwapExecutor(address(swapExecutor));
    }

    // #region test constructor.

    function testConstructorNativeCoinAddressZero() public {
        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );

        router = new ArrakisPrivateVaultRouter(
            address(0),
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );
    }

    function testConstructorPermit2AddressZero() public {
        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );

        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN, address(0), owner, address(factory), WETH
        );
    }

    function testConstructorSwapperAddressZero() public {
        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );

        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );
        vm.prank(owner);
        router.updateSwapExecutor(address(0));
    }

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );

        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            address(0),
            address(factory),
            WETH
        );
    }

    function testConstructorFactoryAddressZero() public {
        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );

        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN, address(PERMIT2), owner, address(0), WETH
        );
    }

    function testConstructor() public {
        assertEq(router.nativeToken(), NATIVE_COIN);
        assertEq(address(router.permit2()), address(PERMIT2));
        assertEq(address(router.swapper()), address(swapExecutor));
        assertEq(router.owner(), owner);
        assertEq(address(router.factory()), address(factory));
    }

    // #endregion test constructor.

    // #region test pause.

    function testPauseOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        router.pause();
    }

    function testPause() public {
        assert(!router.paused());

        vm.prank(owner);
        router.pause();

        assert(router.paused());
    }

    function testPauseWhenNotPaused() public {
        vm.startPrank(owner);
        router.pause();

        vm.expectRevert(Pausable.EnforcedPause.selector);
        router.pause();
        vm.stopPrank();
    }

    // #endregion test pause.

    // #region test unpause.

    function testUnPauseWhenPaused() public {
        vm.expectRevert(Pausable.ExpectedPause.selector);

        router.unpause();
    }

    function testUnPauseOnlyOwner() public {
        // #region pause router.

        vm.prank(owner);
        router.pause();

        // #endregion pause router.

        vm.expectRevert(Ownable.Unauthorized.selector);
        router.unpause();
    }

    function testUnPause() public {
        // #region pause router.

        vm.startPrank(owner);
        router.pause();

        // #endregion pause router.
        assert(router.paused());
        router.unpause();
        assert(!router.paused());

        vm.stopPrank();
    }

    // #endregion test unpause.

    // #region test addLiquidity.

    function testAddLiquidityOnlyPrivateVault() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityOnlyDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityRouterIsNotDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityEmptyAmount() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidity() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(router), 1e18);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.addLiquidity(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testAddLiquidityDeposit1() public {
        // #region create public vault.

        ArrakisPrivateVaultMockBuggy2 vault =
            new ArrakisPrivateVaultMockBuggy2();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(router), 1e18);
        vm.expectRevert(IArrakisPrivateVaultRouter.Deposit1.selector);

        router.addLiquidity(params);
    }

    function testAddLiquidityDeposit0() public {
        // #region create public vault.

        ArrakisPrivateVaultMockBuggy vault =
            new ArrakisPrivateVaultMockBuggy();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 2000e6,
            amount1: 0,
            vault: address(vault)
        });

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);
        vm.expectRevert(IArrakisPrivateVaultRouter.Deposit0.selector);

        router.addLiquidity(params);
    }

    function testAddLiquidityEthAsToken1() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        deal(address(this), 1e18);
        assertEq(address(this).balance, 1e18);
        assertEq(address(vault).balance, 0);

        router.addLiquidity{value: 1e18}(params);

        assertEq(address(vault).balance, 1e18);
        assertEq(address(this).balance, 0);
    }

    function testAddLiquidityEthAsToken0() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        deal(address(this), 1e18);

        assertEq(address(this).balance, 1e18);
        assertEq(address(vault).balance, 0);

        router.addLiquidity{value: 1e18}(params);

        assertEq(address(vault).balance, 1e18);
        assertEq(address(this).balance, 0);
    }

    // #endregion test addLiquidity.

    // #region test swap and add liquidity.

    function testSwapAndAddLiquidityOnlyPublicVault() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityOnlyRouterDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityOnlyDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityEmptyAmounts() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityNotEnoughNativeTokenSent()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(address(this), 1e18);
        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NotEnoughNativeTokenSent
                .selector
        );

        router.swapAndAddLiquidity{value: 1e18 - 1}(params);
    }

    function testSwapAndAddLiquidityNotEnoughNativeTokenSent2()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(address(this), 1e18);
        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NotEnoughNativeTokenSent
                .selector
        );

        router.swapAndAddLiquidity{value: 1e18 - 1}(params);
    }

    function testSwapAndAddLiquidity() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 2e18,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(router), 2e18);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testSwapAndAddLiquidityOneForZeroGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 2e18,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap3.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(router), 2e18);

        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6 + 100e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testSwapAndAddLiquidityZeroForOneGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 4000e6,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap4.selector),
            amountInSwap: 2000e6,
            amountOutSwap: 1e18,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 4000e6);
        IERC20(USDC).approve(address(router), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(WETH).balanceOf(address(this)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18 + 1e17);
    }

    function testSwapAndAddLiquidityEthOneForZeroGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 4000e6,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap5.selector),
            amountInSwap: 2000e6,
            amountOutSwap: 1e18,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 4000e6);
        IERC20(USDC).approve(address(router), 4000e6);

        uint256 balance = address(this).balance;

        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);

        router.swapAndAddLiquidity(params);

        assertEq(address(this).balance - balance, 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18 + 1e17);
    }

    function testSwapAndAddLiquidityEthZeroForOneGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 4000e6,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap6.selector),
            amountInSwap: 2000e6,
            amountOutSwap: 1e18,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 4000e6);
        IERC20(USDC).approve(address(router), 4000e6);

        uint256 balance = address(this).balance;

        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);

        router.swapAndAddLiquidity(params);

        assertEq(address(this).balance - balance, 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18 + 1e17);
    }

    function testSwapAndAddLiquidityEthOneForZero() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 2e18,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap7.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(address(this), 2e18);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);

        router.swapAndAddLiquidity{value: 2e18}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);
    }

    function testSwapAndAddLiquidityEthZeroForOne() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(router));
        vault.addDepositor(address(this));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap8.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(address(this), 2e18);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(address(vault).balance, 0);

        router.swapAndAddLiquidity{value: 2e18}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);
    }

    // #endregion test swap and add liquidity.


    // #region swap mock functions.

    function swap(SwapAndAddData memory params_)
        external
        payable
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        (, bytes memory returnsData) =
            address(this).call(params_.swapData.swapPayload);
        (amount0Diff, amount1Diff) =
            abi.decode(returnsData, (uint256, uint256));
    }

    function swap1() external {
        IERC20(WETH).transferFrom(msg.sender, address(this), 1e18);
        // amount0Diff = 2000e6;
        // amount1Diff = 1e18;
        deal(USDC, address(swapExecutor), 2000e6);
    }

    function swap2()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        IERC20(WETH).transferFrom(msg.sender, address(this), 1e18);
        amount0Diff = 0;
        amount1Diff = 0;
        deal(USDC, address(swapExecutor), 2000e6);
    }

    function swap3() external {
        IERC20(WETH).transferFrom(msg.sender, address(this), 1e18);
        // amount0Diff = 2100e6;
        // amount1Diff = 1e18;
        deal(USDC, address(swapExecutor), 2100e6);
    }


    function swap4() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 2000e6);
        // amount0Diff = 2000e6;
        // amount1Diff = 11e17;
        deal(WETH, address(swapExecutor), 11e17);
    }

    function swap5() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 2000e6);
        // amount0Diff = 11e17;
        // amount1Diff = 2000e6;
        deal(address(swapExecutor), 11e17);
    }

    function swap6() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 2000e6);
        // amount0Diff = 2000e6;
        // amount1Diff = 11e17;
        deal(address(swapExecutor), 11e17);
    }

    function swap7() external payable {
        // amount0Diff = 2000e6;
        // amount1Diff = 1e18;
        deal(USDC, address(swapExecutor), 2000e6);
    }

    function swap8() external payable {
        // amount0Diff = 1e18;
        // amount1Diff = 2000e6;
        deal(USDC, address(swapExecutor), 2000e6);
    }

    // #endregion swap mock functions.
}
