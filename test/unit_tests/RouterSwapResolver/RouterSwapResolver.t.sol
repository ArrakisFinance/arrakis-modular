// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {IArrakisPublicVaultRouter} from
    "../../../src/interfaces/IArrakisPublicVaultRouter.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {RouterSwapResolver} from "../../../src/RouterSwapResolver.sol";
import {IRouterSwapResolver} from
    "../../../src/interfaces/IRouterSwapResolver.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

// #region mocks.
import {RouterMock} from "./mocks/RouterMock.sol";
import {VaultMock} from "./mocks/VaultMock.sol";
// #endregion mocks.

contract RouterSwapResolverTest is TestWrapper {
    // #region constants.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constants.

    RouterSwapResolver public swapResolver;
    address public router;

    address public vault;

    function setUp() public {
        // #region create router mock.

        router = address(new RouterMock());
        vault = address(new VaultMock());

        // #endregion create router mock.

        // #region create RouterSwapResolver.

        swapResolver = new RouterSwapResolver(address(router));

        // #endregion create RouterSwapResolve.
    }

    // #region test constructor.

    function testConstructorRouterAddressZero() public {
        vm.expectRevert(IRouterSwapResolver.AddressZero.selector);
        swapResolver = new RouterSwapResolver(address(0));
    }

    // #endregion test constructor.

    // #region test calculate swap amount.

    function testCalculateSwapAmountCase1() public {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 0;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(amount0, amount1);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 1_000_000_000;
        uint256 price18Decimals = 3000 * 10 ** 18;

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0In,
            amount1In,
            price18Decimals
        );

        assertFalse(zeroForOne);
        assertEq(swapAmount, amount1In);
    }

    function testCalculateSwapAmountCase2() public {
        uint256 amount0 = 0;
        uint256 amount1 = 3_440_000_000;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(amount0, amount1);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 1_000_000_000;
        uint256 price18Decimals = 3000 * 10 ** 18;

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0In,
            amount1In,
            price18Decimals
        );

        assertTrue(zeroForOne);
        assertEq(swapAmount, amount0In);
    }

    function testCalculateSwapAmountCase3() public {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 3_440_000_000;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(amount0, amount1);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 3_440_000_000;
        uint256 price18Decimals = 3440 * 10 ** 18;

        RouterMock(router).setAmounts(1 ether, amount0In, amount1In);

        VaultMock(vault).setTokens(WETH, USDC);

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0In,
            amount1In,
            price18Decimals
        );

        assertFalse(zeroForOne);
        assertEq(swapAmount, 0);
    }

    function testCalculateSwapAmountCase4() public {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 3_440_000_000;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(amount0, amount1);

        // #endregion mocking vault and router.

        uint256 amount0In = FullMath.mulDivRoundingUp(
            1 ether, 3440 * 10 ** 18, 3640 * 10 ** 18
        );
        uint256 amount1In = 3_440_000_000;
        uint256 price18Decimals = 3640 * 10 ** 18;

        RouterMock(router).setAmounts(1 ether, amount0In, amount1In);

        VaultMock(vault).setTokens(WETH, USDC);

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0,
            amount1,
            price18Decimals
        );

        assertTrue(zeroForOne);
        /// we need less USDC to deposit, it why we swap less.
        assertGt(
            (
                1 ether
                    - FullMath.mulDivRoundingUp(
                        1 ether, 3440 * 10 ** 18, 3640 * 10 ** 18
                    )
            ) / 2,
            swapAmount
        );
    }

    function testCalculateSwapAmountCase5() public {
        uint256 amount0 = 1 ether;
        uint256 amount1 = 0;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(amount0, 3_440_000_000);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 3_440_000_000;
        uint256 price18Decimals = 3440 * 10 ** 18;

        RouterMock(router).setAmounts(1 ether, amount0In, amount1In);

        VaultMock(vault).setTokens(WETH, USDC);

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0,
            amount1,
            price18Decimals
        );

        assertTrue(zeroForOne);
        /// we divide by 1000 to get rid of rounding up extra wei.
        assertGt(1 ether / 1000, swapAmount / 1000);
    }

    function testCalculateSwapAmountCase6() public {
        uint256 amount0 = 0;
        uint256 amount1 = 3_440_000_000;

        // #region mocking vault and router.

        VaultMock(vault).setAmounts(1 ether, 3_440_000_000);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 3_440_000_000;
        uint256 price18Decimals = 3440 * 10 ** 18;

        RouterMock(router).setAmounts(1 ether, amount0In, amount1In);

        VaultMock(vault).setTokens(WETH, USDC);

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0,
            amount1,
            price18Decimals
        );

        assertFalse(zeroForOne);
        /// we divide by 100 to get rid of rounding up extra wei.
        assertGt(3_440_000_000 / 100, swapAmount / 100);
    }

    function testCalculateSwapAmountCase7() public {
        uint256 amount0 = 0;
        uint256 amount1 = 3_440_000_000;

        // #region mocking vault and router.

        VaultMock(vault).setInits(1 ether, 3_440_000_000);

        // #endregion mocking vault and router.

        uint256 amount0In = 1 ether;
        uint256 amount1In = 3_440_000_000;
        uint256 price18Decimals = 3440 * 10 ** 18;

        RouterMock(router).setAmounts(1 ether, amount0In, amount1In);

        VaultMock(vault).setTokens(WETH, USDC);

        (bool zeroForOne, uint256 swapAmount) = swapResolver
            .calculateSwapAmount(
            IArrakisMetaVault(vault),
            amount0,
            amount1,
            price18Decimals
        );

        assertFalse(zeroForOne);
        /// we divide by 100 to get rid of rounding up extra wei.
        assertGt(3_440_000_000 / 100, swapAmount / 100);
    }

    // #endregion test calculate swap amount.
}
