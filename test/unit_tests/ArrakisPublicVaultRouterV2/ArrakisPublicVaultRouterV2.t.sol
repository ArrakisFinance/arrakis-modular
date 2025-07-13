// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPublicVaultRouterV2} from
    "../../../src/interfaces/IArrakisPublicVaultRouterV2.sol";
import {
    IPermit2,
    SignatureTransferDetails
} from "../../../src/interfaces/IPermit2.sol";
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";
import {ArrakisPublicVaultRouterV2} from
    "../../../src/ArrakisPublicVaultRouterV2.sol";
import {RouterSwapExecutor} from "../../../src/RouterSwapExecutor.sol";
import {
    AddLiquidityData,
    SwapAndAddData,
    SwapData,
    RemoveLiquidityData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data,
    RemoveLiquidityPermit2Data
} from "../../../src/structs/SRouter.sol";
import {
    PermitBatchTransferFrom,
    PermitTransferFrom,
    TokenPermissions
} from "../../../src/structs/SPermit2.sol";
import {ValantisResolver} from
    "../../../src/modules/resolvers/ValantisResolver.sol";

// #region openzeppelin.
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// #endregion openzeppelin.

// #region solady.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady.

// #region mocks.
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactoryMock.sol";
import {ArrakisPrivateVaultMock} from
    "./mocks/ArrakisPrivateVaultMock.sol";
import {ArrakisPublicVaultMock} from
    "./mocks/ArrakisPublicVaultMock.sol";
// #endregion mocks.

contract ArrakisPublicVaultRouterV2Test is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    IPermit2 public constant PERMIT2 =
        IPermit2(0x000000000022D473030F116dDEE9F6B43aC78BA3);

    // #endregion constant properties.

    // #region public properties.

    ArrakisPublicVaultRouterV2 public router;
    address public resolver;
    RouterSwapExecutor public swapExecutor;
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

        router = new ArrakisPublicVaultRouterV2(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );

        swapExecutor =
            new RouterSwapExecutor(address(router), NATIVE_COIN);

        vm.prank(owner);
        router.updateSwapExecutor(address(swapExecutor));

        resolver = address(new ValantisResolver());

        // #region add resolver.

        address[] memory resolvers = new address[](1);
        resolvers[0] = resolver;

        bytes32[] memory resolverIds = new bytes32[](1);
        resolverIds[0] = bytes32(0);

        vm.prank(owner);
        router.setResolvers(resolverIds, resolvers);

        // #endregion add resolver.
    }

    // #region test constructor.

    function testConstructorNativeCoinAddressZero() public {
        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );

        router = new ArrakisPublicVaultRouterV2(
            address(0),
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );
    }

    function testConstructorPermit2AddressZero() public {
        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );

        router = new ArrakisPublicVaultRouterV2(
            NATIVE_COIN, address(0), owner, address(factory), WETH
        );
    }

    function testConstructorSwapperAddressZero() public {
        router = new ArrakisPublicVaultRouterV2(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );
        vm.prank(owner);
        router.updateSwapExecutor(address(0));
    }

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );

        router = new ArrakisPublicVaultRouterV2(
            NATIVE_COIN,
            address(PERMIT2),
            address(0),
            address(factory),
            WETH
        );
    }

    function testConstructorFactoryAddressZero() public {
        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );

        router = new ArrakisPublicVaultRouterV2(
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

        vm.expectRevert(bytes("Pausable: paused"));
        router.pause();
        vm.stopPrank();
    }

    // #endregion test pause.

    // #region test unpause.

    function testUnPauseWhenPaused() public {
        vm.expectRevert(bytes("Pausable: not paused"));
        vm.prank(owner);
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

    // #region test setResolvers.

    function testSetResolversOnlyOwner() public {
        address notOwner =
            vm.addr(uint256(keccak256(abi.encode("NotOwner"))));
        address[] memory resolvers = new address[](1);
        resolvers[0] = resolver;

        bytes32[] memory ids = new bytes32[](1);
        ids[0] = bytes32(0);

        vm.expectRevert(Ownable.Unauthorized.selector);

        vm.prank(notOwner);
        router.setResolvers(ids, resolvers);
    }

    function testSetResolversUnequalLength() public {
        address[] memory resolvers = new address[](1);
        resolvers[0] = address(0);
        bytes32[] memory ids = new bytes32[](0);

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.UnequalLength.selector
        );

        vm.prank(owner);
        router.setResolvers(ids, resolvers);
    }

    function testSetResolversAddressZero() public {
        address[] memory resolvers = new address[](1);
        resolvers[0] = address(0);
        bytes32[] memory ids = new bytes32[](1);
        ids[0] = bytes32(0);

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.AddressZero.selector
        );

        vm.prank(owner);
        router.setResolvers(ids, resolvers);
    }

    // #endregion test setResolvers.

    // #region test addLiquidity.

    function testAddLiquidityOnlyPublicVault() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityEmptyMaxAmount() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.EmptyMaxAmounts.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityNothingToMint() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(2000e6, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityNothingToMint2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityNothingToMint3() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityBelowMinAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 1 ether + 1,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.BelowMinAmounts.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidityBelowMinAmounts2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18 + 1,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.BelowMinAmounts.selector
        );

        router.addLiquidity(params);
    }

    function testAddLiquidity() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        deal(WETH, address(this), 1e18);
        IERC20(WETH).approve(address(router), 1e18);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.addLiquidity(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testAddLiquidityEthAsToken1() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        deal(address(this), 1e18 * 2);
        assertEq(address(this).balance, 1e18 * 2);
        assertEq(address(vault).balance, 1e18);

        router.addLiquidity{value: 1e18 * 2}(params);

        assertEq(address(vault).balance, 2e18);
        assertEq(address(this).balance, 1e18);
    }

    function testAddLiquidityEthAsToken0() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        deal(address(this), 1e18 * 2);

        assertEq(address(this).balance, 1e18 * 2);
        assertEq(address(vault).balance, 1e18);

        router.addLiquidity{value: 1e18 * 2}(params);

        assertEq(address(vault).balance, 2e18);
        assertEq(address(this).balance, 1e18);
    }

    // #endregion test addLiquidity.

    // #region test swap and add liquidity.

    function testSwapAndAddLiquidityOnlyPublicVault() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityEmptyMaxAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.EmptyMaxAmounts.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityNotEnoughNativeTokenSent()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2
                .NotEnoughNativeTokenSent
                .selector
        );

        router.swapAndAddLiquidity{value: 1e18 - 1}(params);
    }

    function testSwapAndAddLiquidityNotEnoughNativeTokenSent2()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2
                .NotEnoughNativeTokenSent
                .selector
        );

        router.swapAndAddLiquidity{value: 1e18 - 1}(params);
    }

    function testSwapAndAddLiquidity() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testSwapAndAddLiquidityNothingToMint() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap2.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(router), 2e18);

        vm.prank(owner);
        router.updateSwapExecutor(address(this));

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityBelowMinAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
        });

        SwapData memory swapData = SwapData({
            swapPayload: abi.encodeWithSelector(this.swap2.selector),
            amountInSwap: 1e18,
            amountOutSwap: 2000e6,
            swapRouter: address(this),
            zeroForOne: false
        });

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        deal(WETH, address(this), 2e18);
        IERC20(WETH).approve(address(router), 2e18);

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.BelowMinAmounts.selector
        );

        router.swapAndAddLiquidity(params);
    }

    function testSwapAndAddLiquidityOneForZeroGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(USDC).balanceOf(address(this)), 100e6);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testSwapAndAddLiquidityZeroForOneGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 4000e6,
            amount1Max: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.swapAndAddLiquidity(params);

        assertEq(IERC20(WETH).balanceOf(address(this)), 1e17);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testSwapAndAddLiquidityEthOneForZeroGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 4000e6,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(this)
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

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);

        router.swapAndAddLiquidity(params);

        assertEq(address(this).balance - balance, 1e17);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
    }

    function testSwapAndAddLiquidityEthZeroForOneGoodDealOnSwap()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 4000e6,
            amount1Max: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);

        router.swapAndAddLiquidity(params);

        assertEq(address(this).balance - balance, 1e17);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
    }

    function testSwapAndAddLiquidityEthOneForZero() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);

        router.swapAndAddLiquidity{value: 2e18}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
    }

    function testSwapAndAddLiquidityEthZeroForOne() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(vault).balance, 1e18);

        router.swapAndAddLiquidity{value: 2e18}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
    }

    // #endregion test swap and add liquidity.

    // #region test remove liquidity.

    function testRemoveLiquidityOnlyPublicVault() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory params = RemoveLiquidityData({
            burnAmount: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            vault: address(vault),
            receiver: payable(receiver)
        });

        // #endregion create RemoveLiquidityData struct.

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.removeLiquidity(params);
    }

    function testRemoveLiquidityNothingToBurn() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(WETH, address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory params = RemoveLiquidityData({
            burnAmount: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            vault: address(vault),
            receiver: payable(receiver)
        });

        // #endregion create RemoveLiquidityData struct.

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToBurn.selector
        );

        router.removeLiquidity(params);
    }

    function testRemoveLiquidityReceivedBelowMinimum() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(this), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(WETH, address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory params = RemoveLiquidityData({
            burnAmount: 1 ether,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            vault: address(vault),
            receiver: payable(receiver)
        });

        // #endregion create RemoveLiquidityData struct.

        vault.setAmountToGive(2000e6, 1e18);
        IERC20(address(vault)).approve(address(router), 1 ether);

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.ReceivedBelowMinimum.selector
        );

        router.removeLiquidity(params);
    }

    function testRemoveLiquidity() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(this), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory params = RemoveLiquidityData({
            burnAmount: 1 ether,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            vault: address(vault),
            receiver: payable(receiver)
        });

        // #endregion create RemoveLiquidityData struct.

        vault.setAmountToGive(1e18, 2000e6);
        IERC20(address(vault)).approve(address(router), 1 ether);

        assertEq(receiver.balance, 0);
        assertEq(IERC20(USDC).balanceOf(receiver), 0);

        router.removeLiquidity(params);

        assertEq(receiver.balance, 1e18);
        assertEq(IERC20(USDC).balanceOf(receiver), 2000e6);
    }

    // #endregion test remove liquidity.

    // #region test addLiquidityPermit2.

    function testAddLiquidityPermit2OnlyPublicVault() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2EmptyMaxAmount() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.EmptyMaxAmounts.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2NothingToMint() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(2000e6, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2NothingToMint2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2NothingToMint3() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.NothingToMint.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2BelowMinAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 1 ether + 1,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.BelowMinAmounts.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2BelowMinAmounts2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18 + 1,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.BelowMinAmounts.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2LengthMismatch() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.LengthMismatch.selector
        );

        router.addLiquidityPermit2(params);
    }

    function testAddLiquidityPermit2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testAddLiquidityPermit2Bis() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 0);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 0,
            amount0Min: 2000e6,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testAddLiquidityPermit2Bis2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(WETH, address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 1e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);

        router.addLiquidityPermit2(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testAddLiquidityPermit2NativeCoin() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(address(vault), 1e18);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 1e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
        deal(address(this), 1e18 + 100);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(this).balance, 1e18 + 100);

        router.addLiquidityPermit2{value: 1e18 + 100}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
        assertEq(address(this).balance, 100);
    }

    function testAddLiquidityPermit2NativeCoinBis() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(USDC, address(vault), 2000e6);
        deal(address(vault), 1e18);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 2000e6,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
        deal(address(this), 1e18 + 100);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        assertEq(address(this).balance, 1e18 + 100);

        router.addLiquidityPermit2{value: 1e18 + 100}(params);

        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(address(vault).balance, 2e18);
        assertEq(address(this).balance, 100);
    }

    // #endregion test addLiquidityPermit2.

    // #region test swapAndAddLiquidityPermit2.

    function testSwapAndAddLiquidityPermit2OnlyPublicVault() public {
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2EmptyMaxAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 0,
            amount0Min: 0,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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
            IArrakisPublicVaultRouterV2.EmptyMaxAmounts.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2LengthMismatch() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);
        vm.expectRevert(
            IArrakisPublicVaultRouterV2.LengthMismatch.selector
        );

        router.swapAndAddLiquidityPermit2(params);
    }

    function testSwapAndAddLiquidityPermit2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        router.swapAndAddLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testSwapAndAddLiquidityPermit2Bis() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(2000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(2000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 4000e6,
            amount1Max: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
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
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        router.swapAndAddLiquidityPermit2(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    // #endregion test swapAndAddLiquidityPermit2.

    // #region test removeLiquidityPermit2.

    function testRemoveLiquidityPermit2OnlyPublicVault() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create private vault.

        ArrakisPrivateVaultMock vault = new ArrakisPrivateVaultMock();

        // #endregion create private vault

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory removeData = RemoveLiquidityData({
            burnAmount: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            vault: address(vault),
            receiver: payable(receiver)
        });

        TokenPermissions memory permitted =
            TokenPermissions({token: address(vault), amount: 0});

        PermitTransferFrom memory permit = PermitTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        RemoveLiquidityPermit2Data memory params =
        RemoveLiquidityPermit2Data({
            removeData: removeData,
            permit: permit,
            signature: ""
        });

        // #endregion create RemoveLiquidityData struct.

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.OnlyPublicVault.selector
        );

        router.removeLiquidityPermit2(params);
    }

    function testRemoveLiquidityPermit2NothingToBurn() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory removeData = RemoveLiquidityData({
            burnAmount: 0,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            vault: address(vault),
            receiver: payable(receiver)
        });

        TokenPermissions memory permitted =
            TokenPermissions({token: address(vault), amount: 0});

        PermitTransferFrom memory permit = PermitTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        RemoveLiquidityPermit2Data memory params =
        RemoveLiquidityPermit2Data({
            removeData: removeData,
            permit: permit,
            signature: ""
        });

        // #endregion create RemoveLiquidityData struct.

        vm.expectRevert(
            IArrakisPublicVaultRouterV2.NothingToBurn.selector
        );

        router.removeLiquidityPermit2(params);
    }

    function testRemoveLiquidityPermit2() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(this), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        // #region create RemoveLiquidityData struct.

        RemoveLiquidityData memory removeData = RemoveLiquidityData({
            burnAmount: 1 ether,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            vault: address(vault),
            receiver: payable(receiver)
        });

        TokenPermissions memory permitted =
            TokenPermissions({token: address(vault), amount: 1 ether});

        PermitTransferFrom memory permit = PermitTransferFrom({
            permitted: permitted,
            nonce: 1,
            deadline: type(uint256).max
        });

        RemoveLiquidityPermit2Data memory params =
        RemoveLiquidityPermit2Data({
            removeData: removeData,
            permit: permit,
            signature: ""
        });

        // #endregion create RemoveLiquidityData struct.

        vault.setAmountToGive(1e18, 2000e6);

        IERC20(address(vault)).approve(address(PERMIT2), 1 ether);
        assertEq(receiver.balance, 0);
        assertEq(IERC20(USDC).balanceOf(receiver), 0);

        router.removeLiquidityPermit2(params);

        assertEq(receiver.balance, 1e18);
        assertEq(IERC20(USDC).balanceOf(receiver), 2000e6);
    }

    // #endregion test removeLiquidityPermit2.

    // #region test getMintAmounts.

    function testGetMintAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(this), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.

        (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        ) = router.getMintAmounts(address(vault), 1e18, 2000e6);

        assertEq(shareToMint, 1e18);
        assertEq(amount0ToDeposit, 1e18);
        assertEq(amount1ToDeposit, 2000e6);
    }

    // #endregion test getMintAmounts.

    receive() external payable {}

    // #region swapper mock.

    function swap(
        SwapAndAddData memory params_
    )
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
        deal(USDC, address(swapExecutor), 1e18);
    }

    function swap8() external payable {
        // amount0Diff = 1e18;
        // amount1Diff = 2000e6;
        deal(USDC, address(swapExecutor), 1e18);
    }

    function swap9() external {
        IERC20(USDC).transferFrom(msg.sender, address(this), 2000e6);
        // amount0Diff = 2000e6;
        // amount1Diff = 10e17;
        deal(WETH, address(swapExecutor), 10e17);
    }

    // #endregion swapper mock.

    // #region ERC1271 mocks.

    function isValidSignature(
        bytes32,
        bytes memory
    ) external view returns (bytes4 magicValue) {
        magicValue = 0x1626ba7e;
    }

    // #endregion ERC1271 mocks.
}
