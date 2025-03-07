// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {WithdrawHelper} from "../../../src/utils/WithdrawHelper.sol";
import {IWithdrawHelper} from
    "../../../src/interfaces/IWithdrawHelper.sol";
import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";

// #region uniswap v4.

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// #endregion uniswap v4.

// #region mock smart contracts.

import {SafeMock} from "./mocks/SafeMock.sol";
import {VaultMock} from "./mocks/VaultMock.sol";

// #endregion mock smart contracts.

contract WithdrawHelperTest is TestWrapper {
    // #region constant.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public constant USDX =
        0xf3527ef8dE265eAa3716FB312c12847bFBA66Cef;

    //#endregion constant.

    WithdrawHelper public withdrawHelper;

    address public safe;
    address public vault;

    function setUp() public {
        // #region reset fork.

        _reset(vm.envString("ETH_RPC_URL"), 21_906_539);

        // #endregion reset fork.

        // #region mocks.

        withdrawHelper = new WithdrawHelper();

        // #endregion mocks.
    }

    // #region test migrate vault function.

    function testWithdraw_withdraw_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(1);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.WithdrawErr.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_transfer0_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(2);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Transfer0Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_transfer0_err_1() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(USDC, NATIVE_COIN));
        vault = address(new VaultMock(USDC, NATIVE_COIN));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(7);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Transfer0Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_transfer1_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(6);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Transfer1Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_transfer1_err_1() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(7);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Transfer1Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_whitelist_deposit_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove, amount1ToRemove);
        SafeMock(safe).setRevertStep(10);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.WhitelistDepositorErr.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_approval1_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove * 2, amount1ToRemove * 2);
        SafeMock(safe).setRevertStep(11);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Approval1Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_approval1_err_1() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(NATIVE_COIN, USDX));
        vault = address(new VaultMock(NATIVE_COIN, USDX));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove * 2, amount1ToRemove * 2);
        SafeMock(safe).setRevertStep(12);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Approval1Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_approval0_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(USDC, NATIVE_COIN));
        vault = address(new VaultMock(USDC, NATIVE_COIN));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove * 2, amount1ToRemove * 2);
        SafeMock(safe).setRevertStep(11);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Approval0Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_approval0_err_1() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(USDC, NATIVE_COIN));
        vault = address(new VaultMock(USDC, NATIVE_COIN));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove * 2, amount1ToRemove * 2);
        SafeMock(safe).setRevertStep(12);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.Approval0Err.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    function testWithdraw_deposit_err() public {
        address receiver = vm.addr(12);

        uint256 amount0ToRemove = 1_000_000;
        uint256 amount1ToRemove = 10_000_000;

        uint256 total0 = 10_000_000;
        uint256 total1 = 100_000_000;

        // #region setup.

        safe = address(new SafeMock(USDC, NATIVE_COIN));
        vault = address(new VaultMock(USDC, NATIVE_COIN));

        // #endregion setup.

        VaultMock(vault).setAmounts(total0, total1);

        SafeMock(safe).setAmounts(amount0ToRemove * 2, amount1ToRemove * 2);
        SafeMock(safe).setRevertStep(19);

        vm.prank(safe);
        vm.expectRevert(IWithdrawHelper.DepositErr.selector);
        withdrawHelper.withdraw(
            safe,
            vault,
            amount0ToRemove,
            amount1ToRemove,
            payable(receiver)
        );
    }

    // #endregion test migrate vault function.
}
