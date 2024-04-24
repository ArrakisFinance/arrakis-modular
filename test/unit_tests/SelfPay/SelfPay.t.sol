// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

// #region foundry.
import {console} from "forge-std/console.sol";
import {TestWrapper} from "../../utils/TestWrapper.sol";
// #endregion foundry.

import {SelfPay} from "../../../src/SelfPay.sol";
import {ISelfPay} from "../../../src/interfaces/ISelfPay.sol";
import {SetupParams} from "../../../src/structs/SManager.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {BASE} from "../../../src/constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #region mocks.

import {ArrakisMetaVaultPrivateMock} from
    "./mocks/ArrakisMetaVaultPrivateMock.sol";
import {ArrakisStandardManagerMock} from
    "./mocks/ArrakisStandardManagerMock.sol";
import {PalmNFTMock} from "./mocks/PalmNFTMock.sol";
import {TokenMock} from "./mocks/TokenMock.sol";
import {AutomateMock} from "./mocks/AutomateMock.sol";

// #endregion mocks.

contract SelfPayTest is TestWrapper {
    // #region constant.

    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // #endregion constant.

    address public owner;
    address public executor;
    address public feeCollector;
    address public taskCreator;
    address public gelato;

    SelfPay public selfPay;
    IOracleWrapper public oracle;

    ArrakisMetaVaultPrivateMock public vault;
    ArrakisStandardManagerMock public manager;
    PalmNFTMock public palmNFT;
    AutomateMock public automate;

    address public token0;
    address public token1;

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        executor = vm.addr(uint256(keccak256(abi.encode("Executor"))));
        taskCreator =
            vm.addr(uint256(keccak256(abi.encode("TaskCreator"))));
        oracle = IOracleWrapper(
            vm.addr(uint256(keccak256(abi.encode("Oracle"))))
        );
        feeCollector =
            vm.addr(uint256(keccak256(abi.encode("FeeCollector"))));
        gelato = vm.addr(uint256(keccak256(abi.encode("Gelato"))));

        automate = new AutomateMock(feeCollector, weth, gelato);

        // #region initialize mocks contracts.

        _creationMock();

        // #endregion initialize mocks contracts.

        token0 = address(new TokenMock("Token 0", "TKNZ"));
        token1 = weth;

        vault.setTokens(token0, token1);

        vault.setModule(address(vault));

        // #region create selfPay.

        _createSelfPay();

        // #endregion create selfPay.
    }

    // #region selfPay creation.

    function _creationMock() internal {
        // #region initialize mocks contracts.

        vault = new ArrakisMetaVaultPrivateMock();
        manager = new ArrakisStandardManagerMock();
        palmNFT = new PalmNFTMock();

        // #endregion initialize mocks contracts.
    }

    function _createSelfPay() internal {
        selfPay = new SelfPay(
            owner,
            address(vault),
            address(manager),
            address(palmNFT),
            executor,
            address(automate),
            taskCreator,
            weth
        );
    }

    // #endregion selfPay creation.

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        owner = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorVaultAddressZero() public {
        vault = ArrakisMetaVaultPrivateMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorManagerAddressZero() public {
        manager = ArrakisStandardManagerMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorPalmNFTAddressZero() public {
        palmNFT = PalmNFTMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorExecutorAddressZero() public {
        executor = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorWETHAddressZero() public {
        weth = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay();
    }

    function testConstructorCanBeSelfPay() public {
        TokenMock token0 = new TokenMock("Token 0", "TKNZ");
        TokenMock token1 = new TokenMock("Token 1", "TKNO");

        vault.setTokens(address(token0), address(token1));

        // #region create selfPay.

        vm.expectRevert(ISelfPay.CantBeSelfPay.selector);

        _createSelfPay();
    }

    // #endregion test constructor.

    // #region test initialize.

    function testInitializeVaultNFTNotTransferedOrApproved() public {
        // #region set vault info.

        manager.updateVaultInfo(
            SetupParams({
                cooldownPeriod: 60,
                oracle: IOracleWrapper(address(oracle)),
                executor: address(0),
                maxDeviation: 10_000,
                stratAnnouncer: address(this),
                maxSlippagePIPS: 10_000,
                vault: address(0)
            })
        );

        // #endregion set vault info.

        vm.expectRevert(
            ISelfPay.VaultNFTNotTransferedOrApproved.selector
        );

        selfPay.initialize();
    }

    function testInitialize() public {
        // #region set ownership.

        palmNFT.setOwner(address(selfPay));

        // #endregion set ownership.

        // #region set vault info.

        manager.updateVaultInfo(
            SetupParams({
                cooldownPeriod: 60,
                oracle: IOracleWrapper(address(oracle)),
                executor: address(0),
                maxDeviation: 10_000,
                stratAnnouncer: address(this),
                maxSlippagePIPS: 10_000,
                vault: address(0)
            })
        );

        // #endregion set vault info.

        selfPay.initialize();
    }

    // #endregion test initialize.

    // #region test withdraw.

    function testWithdrawOnlyOwner() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        // #region whitelist a depositor.

        vm.prank(owner);
        selfPay.whitelistDepositors(depositors);

        // #endregion whitelist a depositor.

        // #region deposit.

        address module = address(vault.module());

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(module, amount0);
        IERC20(token1).approve(module, amount1);

        vault.deposit(amount0, amount1);

        vm.stopPrank();

        // #endregion deposit.

        vm.expectRevert(Ownable.Unauthorized.selector);

        selfPay.withdraw(BASE, receiver);
    }

    function testWithdraw() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        address[] memory depositors = new address[](1);
        depositors[0] = depositor;

        // #region whitelist a depositor.

        vm.prank(owner);
        selfPay.whitelistDepositors(depositors);

        // #endregion whitelist a depositor.

        // #region deposit.

        address module = address(vault.module());

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(module, amount0);
        IERC20(token1).approve(module, amount1);

        vault.deposit(amount0, amount1);

        vm.stopPrank();

        // #endregion deposit.

        vm.prank(owner);
        selfPay.withdraw(BASE, receiver);
    }

    // #endregion test withdraw.

    // #region test whitelistDepositors.

    function testWhitelistDepositorsOnlyOwner() public {
        address[] memory depositors = new address[](1);
        depositors[0] =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.whitelistDepositors(depositors);
    }

    function testWhitelistDepositors() public {
        address[] memory depositors = new address[](1);
        depositors[0] =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(owner);
        selfPay.whitelistDepositors(depositors);
    }

    // #endregion test whitelistDepositors.

    // #region test blacklistDepositors.

    function testBlacklistDepositorsOnlyOwner() public {
        // #region whitelist depositors.

        address[] memory depositors = new address[](1);
        depositors[0] =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(owner);
        selfPay.whitelistDepositors(depositors);

        // #endregion whitelist depositors.

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.blacklistDepositors(depositors);
    }

    function testBlacklistDepositors() public {
        // #region whitelist depositors.

        address[] memory depositors = new address[](1);
        depositors[0] =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        vm.prank(owner);
        selfPay.whitelistDepositors(depositors);

        // #endregion whitelist depositors.

        vm.prank(owner);
        selfPay.blacklistDepositors(depositors);
    }

    // #endregion test blacklistDepositors.

    // #region test whitelistModules.

    function testWhitelistModulesOnlyOwner() public {
        address[] memory beacons = new address[](1);
        bytes[] memory payloads = new bytes[](1);

        beacons[0] =
            vm.addr(uint256(keccak256(abi.encode("Beacon0"))));
        payloads[0] = "";

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.whitelistModules(beacons, payloads);
    }

    function testWhitelistModules() public {
        address[] memory beacons = new address[](1);
        bytes[] memory payloads = new bytes[](1);

        beacons[0] =
            vm.addr(uint256(keccak256(abi.encode("Beacon0"))));
        payloads[0] = "";

        vm.prank(owner);
        selfPay.whitelistModules(beacons, payloads);
    }

    // #endregion test whitelistModules.

    // #region test blacklistModules.

    function testBlacklistModulesOnlyOwner() public {
        // #region whitelist modules.

        address[] memory beacons = new address[](1);
        bytes[] memory payloads = new bytes[](1);

        beacons[0] =
            vm.addr(uint256(keccak256(abi.encode("Beacon0"))));
        payloads[0] = "";

        vm.prank(owner);
        selfPay.whitelistModules(beacons, payloads);
        // #endregion whitelist modules.

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.blacklistModules(beacons);
    }

    function testBlacklistModules() public {
        // #region whitelist modules.

        address[] memory beacons = new address[](1);
        bytes[] memory payloads = new bytes[](1);

        beacons[0] =
            vm.addr(uint256(keccak256(abi.encode("Beacon0"))));
        payloads[0] = "";

        vm.prank(owner);
        selfPay.whitelistModules(beacons, payloads);
        // #endregion whitelist modules.

        vm.prank(owner);
        selfPay.blacklistModules(beacons);
    }

    // #endregion test blacklistModules.

    // #region test executor.

    function testSetExecutorOnlyOwner() public {
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.setExecutor(executor);
    }

    function testSetExecutorAddressZero() public {
        address executor = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);
        vm.prank(owner);
        selfPay.setExecutor(executor);
    }

    function testSetExecutorSame() public {
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor"))));

        vm.expectRevert(ISelfPay.SameExecutor.selector);
        vm.prank(owner);
        selfPay.setExecutor(executor);
    }

    function testSetExecutor() public {
        address executor =
            vm.addr(uint256(keccak256(abi.encode("Executor2"))));

        vm.prank(owner);
        selfPay.setExecutor(executor);
    }

    // #endregion test setExecutor.

    // #region test callNFT.

    function testCallNFTOnlyOwner() public {
        bytes memory payload = abi.encodeWithSelector(
            PalmNFTMock.setOwner.selector, address(1)
        );

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.callNFT(payload);
    }

    function testCallNFTEmptyData() public {
        bytes memory payload = "";

        vm.expectRevert(ISelfPay.EmptyCallData.selector);
        vm.prank(owner);
        selfPay.callNFT(payload);
    }

    function testCallNFTCallFailed() public {
        bytes memory payload =
            abi.encodeWithSelector(PalmNFTMock.failingCall.selector);

        vm.expectRevert(ISelfPay.CallFailed.selector);
        vm.prank(owner);
        selfPay.callNFT(payload);
    }

    function testCallNFT() public {
        bytes memory payload = abi.encodeWithSelector(
            PalmNFTMock.setOwner.selector, address(1)
        );

        vm.prank(owner);
        selfPay.callNFT(payload);
    }

    // #endregion test callNFT.

    // #region test updateVaultInfo.

    function testUpdateVaultInfoOnlyOwner() public {
        vm.expectRevert(Ownable.Unauthorized.selector);

        selfPay.updateVaultInfo(
            SetupParams({
                cooldownPeriod: 70,
                oracle: IOracleWrapper(address(oracle)),
                executor: address(0),
                maxDeviation: 10_000,
                stratAnnouncer: address(this),
                maxSlippagePIPS: 10_000,
                vault: address(0)
            })
        );
    }

    function testUpdateVaultInfo() public {
        vm.prank(owner);

        selfPay.updateVaultInfo(
            SetupParams({
                cooldownPeriod: 70,
                oracle: IOracleWrapper(address(oracle)),
                executor: address(0),
                maxDeviation: 10_000,
                stratAnnouncer: address(this),
                maxSlippagePIPS: 10_000,
                vault: address(0)
            })
        );
    }

    // #endregion test updateVaultInfo.

    // #region test rebalance.

    // #endregion test rebalance.
}
