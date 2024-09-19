// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

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
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";

// #region openzeppelin.
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
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
    address public constant UNI =
        0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
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

    function testConstructorOwnerIsAddressZero() public {
        vm.expectRevert(
            IArrakisPrivateVaultRouter.AddressZero.selector
        );

        router = new ArrakisPrivateVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            address(0)
        );
    }

    function testConstructor() public {
        assertEq(router.nativeToken(), NATIVE_COIN);
        assertEq(address(router.permit2()), address(PERMIT2));
        assertEq(address(router.swapper()), address(swapExecutor));
        assertEq(router.owner(), owner);
        assertEq(address(router.factory()), address(factory));
        assertEq(address(router.weth()), WETH);
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

    function testPauseWhenPaused() public {
        vm.startPrank(owner);
        router.pause();

        vm.expectRevert(bytes("Pausable: paused"));
        router.pause();
        vm.stopPrank();
    }

    // #endregion test pause.

    // #region test unpause.

    function testUnPauseWhenNotPaused() public {
        vm.expectRevert(bytes("Pausable: not paused"));

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
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.addLiquidity(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
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

    function testAddLiquidityDeposit1ETH() public {
        uint256 amount1 = 1e18;
        // #region create public vault.

        ArrakisPrivateVaultMockBuggy2 vault =
            new ArrakisPrivateVaultMockBuggy2();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(0, amount1);

        // #endregion create public vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: amount1,
            vault: address(vault)
        });

        deal(address(this), amount1);
        vm.expectRevert(IArrakisPrivateVaultRouter.Deposit1.selector);

        router.addLiquidity{value: amount1}(params);
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

    function testAddLiquidityDeposit0ETH() public {
        // #region create public vault.

        ArrakisPrivateVaultMockBuggy vault =
            new ArrakisPrivateVaultMockBuggy();
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
        vm.expectRevert(IArrakisPrivateVaultRouter.Deposit0.selector);

        router.addLiquidity{value: 1e18}(params);
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
        assertEq(
            IERC20(USDC).balanceOf(address(vault)), 2000e6 + 100e6
        );
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

    // #region test addLiquidityPermit2.

    function testAddLiquidityPermit2OnlyPrivateVault() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2OnlyDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.

        factory.addPrivateVault(address(vault));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2RouterDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.

        factory.addPrivateVault(address(vault));

        // #region add caller as depositor.

        vault.addDepositor(address(this));

        // #endregion add caller as depositor.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2EmptyAmount() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.

        factory.addPrivateVault(address(vault));

        // #region add caller as depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add caller as depositor.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2LengthMismatch() public {
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

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](3);
        permitted[0] = TokenPermissions({token: WETH, amount: 1e18});
        permitted[1] = TokenPermissions({token: WETH, amount: 1e18});
        permitted[2] = TokenPermissions({token: WETH, amount: 1e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(PERMIT2), 1e18);
        vm.expectRevert(
            IArrakisPrivateVaultRouter.LengthMismatch.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: WETH, amount: 1e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(PERMIT2), 1e18);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testAddLiquidityPermit2Bis() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 0);

        // #endregion create private vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testAddLiquidityPermit2Bis2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](2);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});
        permitted[1] = TokenPermissions({token: WETH, amount: 1e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6);
        deal(WETH, address(this), 1e18);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        IERC20(WETH).approve(address(PERMIT2), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    // #endregion test addLiquidityPermit2.

    // #region test swapAndAddLiquidityPermit2.

    function testSwapAndAddLiquidityPermit2OnlyPrivateVault()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2OnlyDepositor() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        factory.addPrivateVault(address(vault));

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2OnlyRouterAsDepositor()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        factory.addPrivateVault(address(vault));

        // #region add depositor.

        vault.addDepositor(address(this));

        // #endregion add depositor.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2EmptyMaxAmounts() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        vault.addDepositor(address(this));
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2LengthMismatch() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](3);
        permitted[0] = TokenPermissions({token: WETH, amount: 2e18});
        permitted[1] = TokenPermissions({token: WETH, amount: 2e18});
        permitted[2] = TokenPermissions({token: WETH, amount: 2e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(PERMIT2), 2e18);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);
        vm.expectRevert(
            IArrakisPrivateVaultRouter.LengthMismatch.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: WETH, amount: 2e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(PERMIT2), 2e18);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.swapAndAddLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testSwapAndAddLiquidityPermit2Bis() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create private vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 4000e6,
            amount1: 0,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap9.selector),
            amountInSwap: 2000e6,
            amountOutSwap: 1e18,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 4000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 4000e6);
        IERC20(USDC).approve(address(PERMIT2), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.swapAndAddLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    // #endregion test swapAndAddLiquidityPermit2.

    // #region test wrapAndAddLiquidity.

    function testWethAndAddLiquidityOnlyPrivateVault() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityOnlyDepositor() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        factory.addPrivateVault(address(vault));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityRouterNotDepositor() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        factory.addPrivateVault(address(vault));

        vault.addDepositor(address(this));

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityMsgValueZero() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
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
            IArrakisPrivateVaultRouter.MsgValueZero.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityEmptyAmounts() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNativeTokenNotSupported()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNativeTokenNotSupported2()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNoWethToken() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(UNI, USDC);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNoWethToken2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, UNI);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidity() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.

        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testWethAndAddLiquidity2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
    }

    function testWethAndAddLiquidity3() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);
        deal(USDC, address(this), 2000e6);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 2000e6,
            amount1: 1e18,
            vault: address(vault)
        });

        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testWethAndAddLiquidity4() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 2000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);
        deal(USDC, address(this), 2000e6);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 2000e6,
            vault: address(vault)
        });

        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testWethAndAddLiquidityWethToken1SentTooMuch() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    function testWethAndAddLiquidityWethToken1SentTooMuch2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    // #endregion test wrapAndAddLiquidity.

    // #region test wrapAndSwapAndAddLiquidity.

    function testWethAndSwapAndAddLiquidityOnlyPrivateVault()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

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

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityOnlyDepositor() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add private vault into factory.

        factory.addPrivateVault(address(vault));

        // #endregion add private vault into factory.

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

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityOnlyRouterDepositor()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add private vault into factory.

        factory.addPrivateVault(address(vault));

        // #endregion add private vault into factory.
        // #region add depositor.

        vault.addDepositor(address(this));

        // #endregion add depositor.

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

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityMsgValueZero() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

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
            IArrakisPrivateVaultRouter.MsgValueZero.selector
        );

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityEmptyMaxAmounts() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNativeTokenNotSupported()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNativeTokenNotSupported2()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNoWethToken() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(UNI, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPrivateVaultRouter.NoWethToken.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidity() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testWethAndSwapAndAddLiquidity2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
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

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAndSwapAndAddLiquidity3() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18,
            amount1: 2000e6,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1Bis.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAndSwapAndAddLiquidity4() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18 + 10,
            amount1: 2000e6,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1Bis.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18 + 10);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 2e18 + 10);
    }

    function testWethAndSwapAndAddLiquidity5() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 2e18 + 10,
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

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18 + 10);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 2e18 + 10);
    }

    function testWethAndSwapAndAddLiquidity6() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6 + 10,
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

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(router), 2000e6 + 10);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6 + 10);
        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
    }

    function testWethAndSwapAndAddLiquidity7() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18,
            amount1: 2000e6 + 10,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1Bis.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(router), 2000e6 + 10);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6 + 10);
        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
    }

    // #endregion test wrapAndSwapAndAddLiquidity.

    // #region test wrapAndAddLiquidityPermit2.

    function testWethAddLiquidityPermit2OnlyPrivateVault() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.wrapAndAddLiquidityPermit2(params);
    }

    function testWethAddLiquidityPermit2OnlyDepositor() public {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add private vault.

        factory.addPrivateVault(address(vault));

        // #endregion add private vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.wrapAndAddLiquidityPermit2(params);
    }

    function testWethAddLiquidityPermit2RouterIsDepositor() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add private vault.

        factory.addPrivateVault(address(vault));

        // #endregion add private vault.
        // #region add as depositors.

        vault.addDepositor(address(this));

        // #endregion add as depositors.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.wrapAndAddLiquidityPermit2(params);
    }

    function testWethAddLiquidityPermit2EmptyAmounts() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NativeTokenNotSupported()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NativeTokenNotSupported2()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NoWethToken() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(UNI, USDC);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 1e18,
            amount1: 0,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2LengthMismatch() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](2);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.LengthMismatch.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2Permit2WethNotAuthorized()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 0,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: WETH, amount: 1e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(PERMIT2), 1e18);
        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .Permit2WethNotAuthorized
                .selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
    }

    function testWethAddLiquidityPermit2Bis() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(2000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 1e18,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2100e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    function testWethAddLiquidityPermit2Bis2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositor.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositor.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 1e18,
            amount1: 2000e6,
            vault: address(vault)
        });

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        AddLiquidityPermit2Data memory params =
        AddLiquidityPermit2Data({
            addData: addData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2100e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    // #endregion test wrapAndAddLiquidityPermit2.

    // #region test wrapAndSwapAndAddLiquidityPermit2.

    function testWethSwapAndAddLiquidityPermit2OnlyPrivateVault()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyPrivateVault.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2OnlyDepositor()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add as private vault.

        factory.addPrivateVault(address(vault));

        // #endregion add as private vault.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.OnlyDepositor.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2RouterIsDepositor()
        public
    {
        // #region create public vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create public vault.
        // #region add as private vault.

        factory.addPrivateVault(address(vault));

        // #endregion add as private vault.
        // #region add depositors.

        vault.addDepositor(address(this));

        // #endregion add depositors.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.RouterIsNotDepositor.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2MsgValueZero()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.

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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.MsgValueZero.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2EmptyAmounts()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.EmptyAmounts.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NativeTokenNotSupported(
    ) public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NativeTokenNotSupported2(
    ) public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .NativeTokenNotSupported
                .selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NoWethToken() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(UNI, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.NoWethToken.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2LengthMismatch()
        public
    {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](0);

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        vm.expectRevert(
            IArrakisPrivateVaultRouter.LengthMismatch.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2Permit2WethNotAuthorized(
    ) public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: WETH, amount: 1e18});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(PERMIT2), 1e18);
        vm.expectRevert(
            IArrakisPrivateVaultRouter
                .Permit2WethNotAuthorized
                .selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethSwapAndAddLiquidityPermit2Bis() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6,
            amount1: 2e18 + 10,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18 + 10);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 2e18 + 10);
    }

    function testWethSwapAndAddLiquidityPermit2Bis2() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setModule(address(vault));
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2000e6 + 10,
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

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] =
            TokenPermissions({token: USDC, amount: 2000e6 + 10});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(PERMIT2), 2000e6 + 10);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6 + 10);
        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
    }

    function testWethSwapAndAddLiquidityPermit2Bis3() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18,
            amount1: 2000e6 + 10,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1Bis.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] =
            TokenPermissions({token: USDC, amount: 2000e6 + 10});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(PERMIT2), 2000e6 + 10);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6 + 10);
        assertEq(IERC20(USDC).balanceOf(address(this)), 0);
    }

    function testWethSwapAndAddLiquidityPermit2Bis4() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();
        vault.setTokens(WETH, USDC);
        vault.setModule(address(vault));
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPrivateVault(address(vault));

        // #endregion add vault to mock factory.
        // #region add depositors.

        vault.addDepositor(address(this));
        vault.addDepositor(address(router));

        // #endregion add depositors.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0: 2e18 + 10,
            amount1: 2000e6,
            vault: address(vault)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap1Bis.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: true
        });

        SwapAndAddData memory swapAndAddData =
            SwapAndAddData({swapData: swapData, addData: addData});

        TokenPermissions[] memory permitted =
            new TokenPermissions[](1);
        permitted[0] = TokenPermissions({token: USDC, amount: 2000e6});

        PermitBatchTransferFrom memory permit =
        PermitBatchTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        SwapAndAddPermit2Data memory params = SwapAndAddPermit2Data({
            swapAndAddData: swapAndAddData,
            permit: permit,
            signature: ""
        });

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(PERMIT2), 2000e6 + 10);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 0);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 0);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18 + 10);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 2e18 + 10);
    }

    // #endregion test wrapAndSwapAndAddLiquidityPermit2.

    receive() external payable {}

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

    function swap1Bis()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 1e18;
        amount1Diff = 2000e6;
        IERC20(WETH).transferFrom(msg.sender, address(this), 1e18);
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

    function swap9() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 2000e6);
        // amount0Diff = 2000e6;
        // amount1Diff = 10e17;
        deal(WETH, address(swapExecutor), 10e17);
    }

    // #endregion swap mock functions.

    // #region ERC1271 mocks.

    function isValidSignature(
        bytes32,
        bytes memory
    ) external view returns (bytes4 magicValue) {
        magicValue = 0x1626ba7e;
    }

    // #endregion ERC1271 mocks.
}