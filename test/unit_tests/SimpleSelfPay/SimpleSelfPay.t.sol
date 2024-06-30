// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {SimpleSelfPay} from "../../../src/SimpleSelfPay.sol";
import {ISimpleSelfPay} from
    "../../../src/interfaces/ISimpleSelfPay.sol";

import {NATIVE_COIN} from "../../../src/constants/CArrakis.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// #region mocks.

import {AutomateMock} from "./mocks/AutomateMock.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManagerMock.sol";
import {ArrakisMetaVaultPrivateMock} from
    "./mocks/ArrakisMetaVaultPrivateMock.sol";

// #endregion mocks.

contract SimpleSelfPayTest is TestWrapper {
    using Address for address payable;

    // #region constant.

    address public constant weth =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constant.

    address public automate;
    address public manager;
    address public vault;

    address public executor;
    address public receiver;
    address public taskCreator;

    address public feeCollector;
    address public gelato;

    SimpleSelfPay public simpleSelfPay;

    function setUp() public {
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        taskCreator =
            vm.addr(uint256(keccak256(abi.encode("Task Creator"))));

        feeCollector =
            vm.addr(uint256(keccak256(abi.encode("FeeCollector"))));
        gelato = vm.addr(uint256(keccak256(abi.encode("Gelato"))));

        // #region mock automate.

        automate = address(
            new AutomateMock(feeCollector, NATIVE_COIN, gelato)
        );

        // #endregion mock automate.

        // #region mock manager.

        manager = address(new ArrakisStandardManagerMock());

        // #endregion mock manager.

        // #region mock vault.

        vault = address(new ArrakisMetaVaultPrivateMock());

        // #endregion mock vault.

        simpleSelfPay = new SimpleSelfPay(
            automate, taskCreator, executor, manager, vault, receiver
        );
    }

    // #region test constructor.

    function testConstructorAddressZeroVault() public {
        vm.expectRevert(ISimpleSelfPay.AddressZero.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate,
            taskCreator,
            executor,
            manager,
            address(0),
            receiver
        );
    }

    function testConstructorAddressZeroManager() public {
        vm.expectRevert(ISimpleSelfPay.AddressZero.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate,
            taskCreator,
            executor,
            address(0),
            vault,
            receiver
        );
    }

    function testConstructorAddressZeroExecutor() public {
        vm.expectRevert(ISimpleSelfPay.AddressZero.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate,
            taskCreator,
            address(0),
            manager,
            vault,
            receiver
        );
    }

    function testConstructorAddressZeroTaskCreator() public {
        vm.expectRevert(ISimpleSelfPay.AddressZero.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate, address(0), executor, manager, vault, receiver
        );
    }

    function testConstructorAddressZeroReceiver() public {
        vm.expectRevert(ISimpleSelfPay.AddressZero.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate,
            taskCreator,
            executor,
            manager,
            vault,
            address(0)
        );
    }

    function testConstructorCantBeSelfPay() public {
        address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        automate =
            address(new AutomateMock(feeCollector, USDC, gelato));

        vm.expectRevert(ISimpleSelfPay.CantBeSelfPay.selector);
        simpleSelfPay = new SimpleSelfPay(
            automate, taskCreator, executor, manager, vault, receiver
        );
    }

    // #endregion test constructor.

    // #region test sendBackETH.

    function testSendBackETHOnlyReceiver() public {
        address notReceiver =
            vm.addr(uint256(keccak256(abi.encode("Not Receiver"))));
        // #region send ETH to simple self pay.

        deal(address(this), 1 ether);

        payable(address(simpleSelfPay)).sendValue(1 ether);

        // #endregion send ETH to simple self pay.

        vm.expectRevert(ISimpleSelfPay.OnlyReceiver.selector);
        vm.prank(notReceiver);

        simpleSelfPay.sendBackETH(1 ether);
    }

    function testSendBackETHNotEnoughToSendBack() public {
        // #region send ETH to simple self pay.

        deal(address(this), 1 ether);

        payable(address(simpleSelfPay)).sendValue(1 ether);

        // #endregion send ETH to simple self pay.

        vm.prank(receiver);
        vm.expectRevert(ISimpleSelfPay.NotEnoughToSendBack.selector);
        simpleSelfPay.sendBackETH(1 ether + 1);
    }

    function testSendBackETH() public {
        // #region send ETH to simple self pay.

        deal(address(this), 1 ether);

        payable(address(simpleSelfPay)).sendValue(1 ether);

        // #endregion send ETH to simple self pay.

        uint256 balance = receiver.balance;

        assertEq(balance, 0);

        vm.prank(receiver);
        simpleSelfPay.sendBackETH(1 ether);

        balance = receiver.balance;

        assertEq(balance, 1 ether);
    }

    // #endregion test sendBackETH.

    // #region test rebalance.

    function testRebalanceOnlyExecutor() public {
        address notExecutor =
            vm.addr(uint256(keccak256(abi.encode("Not Executor"))));
        // #region fill gas tank.

        deal(address(this), 1 ether);

        payable(address(simpleSelfPay)).sendValue(1 ether);

        // #endregion fill gas tank.

        // #region mock automate.

        AutomateMock(automate).setFee(0.5 ether);

        // #endregion mock automate.

        bytes[] memory payloads = new bytes[](0);

        vm.prank(notExecutor);
        vm.expectRevert(ISimpleSelfPay.OnlyExecutor.selector);

        simpleSelfPay.rebalance(payloads);
    }

    function testRebalance() public {
        // #region fill gas tank.

        deal(address(this), 1 ether);

        payable(address(simpleSelfPay)).sendValue(1 ether);

        // #endregion fill gas tank.

        // #region mock automate.

        uint256 fee = 0.5 ether;

        AutomateMock(automate).setFee(fee);

        // #endregion mock automate.

        bytes[] memory payloads = new bytes[](0);

        uint256 balance = gelato.balance;

        assertEq(balance, 0);

        vm.prank(executor);

        simpleSelfPay.rebalance(payloads);

        balance = gelato.balance;

        assertEq(balance, fee);
    }

    // #endregion test rebalance.
}
