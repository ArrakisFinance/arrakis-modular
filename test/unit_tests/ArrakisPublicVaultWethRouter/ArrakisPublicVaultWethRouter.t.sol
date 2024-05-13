// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPublicVaultRouter} from
    "../../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {IPermit2} from "../../../src/interfaces/IPermit2.sol";
import {IWETH9} from "../../../src/interfaces/Iweth9.sol";
import {
    ArrakisPublicVaultRouter,
    AddLiquidityData,
    SwapAndAddData,
    AddLiquidityPermit2Data,
    SwapAndAddPermit2Data
} from "../../../src/ArrakisPublicVaultRouter.sol";
import {SwapData} from "../../../src/structs/SRouter.sol";
import {
    TokenPermissions,
    PermitBatchTransferFrom,
    PermitTransferFrom
} from "../../../src/structs/SPermit2.sol";
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";

// #region openzeppelin.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #endregion openzeppelin.

// #region mocks.
import {ArrakisMetaVaultFactoryMock} from
    "./mocks/ArrakisMetaVaultFactoryMock.sol";
import {ArrakisPrivateVaultMock} from
    "./mocks/ArrakisPrivateVaultMock.sol";
import {ArrakisPublicVaultMock} from
    "./mocks/ArrakisPublicVaultMock.sol";
// #endregion mocks.

contract ArrakisPublicVaultRouterTest is TestWrapper {
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

    ArrakisPublicVaultRouter public router;
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

        router = new ArrakisPublicVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            WETH
        );

        vm.prank(owner);
        router.updateSwapExecutor(address(this));
    }

    // #region test constructor.

    function testConstructorWethAddressZero() public {
        vm.expectRevert(
            IArrakisPublicVaultRouter.AddressZero.selector
        );

        router = new ArrakisPublicVaultRouter(
            NATIVE_COIN,
            address(PERMIT2),
            owner,
            address(factory),
            address(0)
        );
    }

    // #endregion test constructor.

    // #region test wrapAndAddLiquidity.

    function testWethAndAddLiquidityOnlyPublicVault() public {
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
            IArrakisPublicVaultRouter.OnlyPublicVault.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityMsgValueZero() public {
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
            IArrakisPublicVaultRouter.MsgValueZero.selector
        );

        router.wrapAndAddLiquidity(params);
    }

    function testWethAndAddLiquidityEmptyMaxAmounts() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.EmptyMaxAmounts.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNothingToMint() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(2000e6, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.NothingToMint.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNothingToMint2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.NothingToMint.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNothingToMint3() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.NothingToMint.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityBelowMinAmounts() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.BelowMinAmounts.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityBelowMinAmounts2() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.BelowMinAmounts.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNativeTokenNotSupported()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        deal(address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNativeTokenNotSupported2()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        deal(address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNoWethToken() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(UNI, USDC);
        vault.mintLPToken(address(1), 1 ether);
        deal(UNI, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidityNoWethToken2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, UNI);
        vault.mintLPToken(address(1), 1 ether);
        deal(UNI, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        vm.expectRevert(
            IArrakisPublicVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );
    }

    function testWethAndAddLiquidity() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testWethAndAddLiquidity2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
    }

    function testWethAndAddLiquidity3() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);
        deal(USDC, address(this), 2000e6);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 1e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
        });

        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAndAddLiquidity4() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);
        deal(USDC, address(this), 2000e6);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 2000e6,
            amount0Min: 1e18,
            amount1Min: 2000e6,
            amountSharesMin: 1 ether,
            vault: address(vault),
            receiver: address(0)
        });

        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAndAddLiquidityWethToken1SentTooMuch() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 1e18,
            amount0Min: 0,
            amount1Min: 1e18,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    function testWethAndAddLiquidityWethToken1SentTooMuch2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory params = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
            amount1Min: 0,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
        });

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidity{value: wethAmountToWrapAndAdd}(
            params
        );

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    // #endregion test wrapAndAddLiquidity.

    // #region test wrapAndSwapAndAddLiquidity.

    function testWethAndSwapAndAddLiquidityOnlyPublicVault() public {
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
            IArrakisPublicVaultRouter.OnlyPublicVault.selector
        );

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityMsgValueZero() public {
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

        SwapAndAddData memory params =
            SwapAndAddData({swapData: swapData, addData: addData});

        vm.expectRevert(
            IArrakisPublicVaultRouter.MsgValueZero.selector
        );

        router.wrapAndSwapAndAddLiquidity(params);
    }

    function testWethAndSwapAndAddLiquidityEmptyMaxAmounts() public {
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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
            IArrakisPublicVaultRouter.EmptyMaxAmounts.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNativeTokenNotSupported()
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNativeTokenNotSupported2()
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

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityNoWethToken() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(UNI, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(UNI, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPublicVaultRouter.NoWethToken.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityMsgValueDTMaxAmount()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 1e18 + 1;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPublicVaultRouter.MsgValueDTMaxAmount.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidityMsgValueDTMaxAmount2()
        public
    {
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

        uint256 wethAmountToWrapAndAdd = 1e18 + 1;

        deal(address(this), wethAmountToWrapAndAdd);

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

        vm.expectRevert(
            IArrakisPublicVaultRouter.MsgValueDTMaxAmount.selector
        );

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAndSwapAndAddLiquidity() public {
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

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 0,
            amount1Max: 2e18,
            amount0Min: 2000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAndSwapAndAddLiquidity2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 2e18,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
    }

    function testWethAndSwapAndAddLiquidity3() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 4000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(1e18, 4000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18,
            amount1Max: 2000e6,
            amount0Min: 1e18,
            amount1Min: 4000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
    }

    function testWethAndSwapAndAddLiquidity4() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 4000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(1e18, 4000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18 + 10,
            amount1Max: 2000e6,
            amount0Min: 1e18,
            amount1Min: 4000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(balanceBefore - balanceAfter, 2e18);
    }

    function testWethAndSwapAndAddLiquidity5() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 2e18 + 10,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        deal(USDC, address(this), 2000e6);
        IERC20(USDC).approve(address(router), 2000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(balanceBefore - balanceAfter, 2e18);
    }

    function testWethAndSwapAndAddLiquidity6() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6 + 10,
            amount1Max: 2e18,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        deal(USDC, address(this), 2000e6 + 10);
        IERC20(USDC).approve(address(router), 2000e6 + 10);

        router.wrapAndSwapAndAddLiquidity{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(IERC20(USDC).balanceOf(address(this)), 10);
    }

    function testWethAndSwapAndAddLiquidity7() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 4000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(1e18, 4000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18,
            amount1Max: 2000e6 + 10,
            amount0Min: 1e18,
            amount1Min: 4000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(IERC20(USDC).balanceOf(address(this)), 10);
    }

    // #endregion test wrapAndSwapAndAddLiquidity.

    // #region test wrapAndAddLiquidityPermit2.

    function testWethAddLiquidityPermit2OnlyPublicVault() public {
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
            IArrakisPublicVaultRouter.OnlyPublicVault.selector
        );

        router.wrapAndAddLiquidityPermit2(params);
    }

    function testWethAddLiquidityPermit2MsgValueZero() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.
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
            IArrakisPublicVaultRouter.MsgValueZero.selector
        );

        router.wrapAndAddLiquidityPermit2(params);
    }

    function testWethAddLiquidityPermit2EmptyMaxAmounts() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.EmptyMaxAmounts.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NothingToMint() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
            IArrakisPublicVaultRouter.NothingToMint.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2BelowMinAmounts() public {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
            IArrakisPublicVaultRouter.BelowMinAmounts.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2BelowMinAmounts2() public {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
            IArrakisPublicVaultRouter.BelowMinAmounts.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NativeTokenNotSupported()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        deal(address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NativeTokenNotSupported2()
        public
    {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        deal(address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
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
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2NoWethToken() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(UNI, USDC);
        vault.mintLPToken(address(1), 1 ether);
        deal(UNI, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 1e18,
            amount1Max: 0,
            amount0Min: 1e18,
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
            IArrakisPublicVaultRouter.NoWethToken.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2LengthMismatch() public {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
            IArrakisPublicVaultRouter.LengthMismatch.selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2Permit2WethNotAuthorized()
        public
    {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
        vm.expectRevert(
            IArrakisPublicVaultRouter
                .Permit2WethNotAuthorized
                .selector
        );

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethAddLiquidityPermit2() public {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
    }

    function testWethAddLiquidityPermit2Bis() public {
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
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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

        deal(USDC, address(this), 2100e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    function testWethAddLiquidityPermit2Bis2() public {
        // #region create public vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 2000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 2000e6);
        vault.setInits(1e18, 2000e6);

        // #endregion create public vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.

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

        deal(USDC, address(this), 2100e6);
        IERC20(USDC).approve(address(PERMIT2), 2000e6);
        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 2000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);
        assertEq(balanceBefore - balanceAfter, 1e18);
    }

    // #endregion test wrapAndAddLiquidityPermit2.

    // #region test wrapAndSwapAndAddLiquidityPermit2.

    function testWethSwapAndAddLiquidityPermit2OnlyPublicVault()
        public
    {
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
            IArrakisPublicVaultRouter.OnlyPublicVault.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2MsgValueZero()
        public
    {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.
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
            IArrakisPublicVaultRouter.MsgValueZero.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2(params);
    }

    function testWethSwapAndAddLiquidityPermit2EmptyMaxAmounts()
        public
    {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.EmptyMaxAmounts.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NativeTokenNotSupported(
    ) public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, NATIVE_COIN);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NativeTokenNotSupported2(
    ) public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(NATIVE_COIN, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.NativeTokenNotSupported.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2NoWethToken() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(UNI, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(UNI, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.NoWethToken.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2MsgValueDTMaxAmount()
        public
    {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 0);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(1e18, 0);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 1;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            zeroForOne: true
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
            IArrakisPublicVaultRouter.MsgValueDTMaxAmount.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2MsgValueDTMaxAmount2()
        public
    {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18 + 1;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.MsgValueDTMaxAmount.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2LengthMismatch()
        public
    {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter.LengthMismatch.selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2Permit2WethNotAuthorized(
    ) public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(0, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        vault.setInits(0, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 1e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
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
            IArrakisPublicVaultRouter
                .Permit2WethNotAuthorized
                .selector
        );

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);
    }

    function testWethSwapAndAddLiquidityPermit2() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 2e18,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
    }

    function testWethSwapAndAddLiquidityPermit2Bis() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6,
            amount1Max: 2e18 + 10,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(balanceBefore - balanceAfter, 2e18);
    }

    function testWethSwapAndAddLiquidityPermit2Bis2() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(USDC, WETH);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(4000e6, 1e18);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(4000e6, 1e18);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2000e6 + 10,
            amount1Max: 2e18,
            amount0Min: 4000e6,
            amount1Min: 1e18,
            amountSharesMin: 0,
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(IERC20(USDC).balanceOf(address(this)), 10);
    }

    function testWethSwapAndAddLiquidityPermit2Bis3() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 4000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18,
            amount1Max: 2000e6 + 10,
            amount0Min: 1e18,
            amount1Min: 4000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(IERC20(USDC).balanceOf(address(this)), 10);
    }

    function testWethSwapAndAddLiquidityPermit2Bis4() public {
        // #region create private vault.

        ArrakisPublicVaultMock vault = new ArrakisPublicVaultMock();
        vault.setTokens(WETH, USDC);
        vault.mintLPToken(address(1), 1 ether);
        vault.setAmountToTake(1e18, 4000e6);
        vault.setModule(address(vault));
        deal(WETH, address(vault), 1e18);
        deal(USDC, address(vault), 4000e6);
        vault.setInits(1e18, 4000e6);

        // #endregion create private vault.
        // #region add vault to mock factory.

        factory.addPublicVault(address(vault));

        // #endregion add vault to mock factory.
        // #region increase eth balance.

        uint256 wethAmountToWrapAndAdd = 2e18 + 10;

        deal(address(this), wethAmountToWrapAndAdd);

        // #endregion increase eth balance.
        AddLiquidityData memory addData = AddLiquidityData({
            amount0Max: 2e18 + 10,
            amount1Max: 2000e6,
            amount0Min: 1e18,
            amount1Min: 4000e6,
            amountSharesMin: 0,
            vault: address(vault),
            receiver: address(0)
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

        assertEq(IERC20(WETH).balanceOf(address(vault)), 1e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 4000e6);

        uint256 balanceBefore = address(this).balance;

        router.wrapAndSwapAndAddLiquidityPermit2{
            value: wethAmountToWrapAndAdd
        }(params);

        uint256 balanceAfter = address(this).balance;

        assertEq(IERC20(WETH).balanceOf(address(vault)), 2e18);
        assertEq(IERC20(USDC).balanceOf(address(vault)), 8000e6);
        assertEq(balanceBefore - balanceAfter, 2e18);
    }

    // #endregion test wrapAndSwapAndAddLiquidityPermit2.

    /// @dev to receiver ether.
    receive() external payable {}

    // #region swapper mock.

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

    function swap1()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2000e6;
        amount1Diff = 1e18;
        deal(USDC, address(this), 2000e6);
        IERC20(USDC).transfer(address(router), 2000e6);
    }

    function swap1Bis()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 1e18;
        amount1Diff = 2000e6;
        deal(USDC, address(this), 2000e6);
        IERC20(USDC).transfer(address(router), 2000e6);
    }

    function swap2()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 0;
        amount1Diff = 0;
        deal(USDC, address(router), 2000e6);
    }

    function swap3()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2100e6;
        amount1Diff = 1e18;
        deal(USDC, address(router), 2100e6);
    }

    function swap4()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2000e6;
        amount1Diff = 11e17;
        deal(WETH, address(router), 11e17);
    }

    function swap5()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 11e17;
        amount1Diff = 2000e6;
        deal(address(router), 11e17);
    }

    function swap6()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2000e6;
        amount1Diff = 11e17;
        deal(address(router), 11e17);
    }

    function swap7()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2000e6;
        amount1Diff = 1e18;
        deal(USDC, address(router), 1e18);
    }

    function swap8()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 1e18;
        amount1Diff = 2000e6;
        deal(USDC, address(router), 1e18);
    }

    function swap9()
        external
        returns (uint256 amount0Diff, uint256 amount1Diff)
    {
        amount0Diff = 2000e6;
        amount1Diff = 10e17;
        deal(WETH, address(router), 10e17);
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
