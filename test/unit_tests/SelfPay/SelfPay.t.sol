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
import {OracleWrapperMock} from "./mocks/OracleWrapperMock.sol";
import {PalmNFTMock} from "./mocks/PalmNFTMock.sol";
import {ArrakisPrivateVaultRouterMock} from
    "./mocks/ArrakisPrivateVaultRouterMock.sol";
import {TokenMock} from "./mocks/TokenMock.sol";

// #endregion mocks.

contract SelfPayTest is TestWrapper {
    // #region constant.

    address public usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address public weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 public buffer = 10_000;

    // #endregion constant.

    address public owner;
    address public w3f;
    address public receiver;
    SelfPay public selfPay;

    ArrakisMetaVaultPrivateMock public vault;
    ArrakisStandardManagerMock public manager;
    OracleWrapperMock public oracle;
    PalmNFTMock public palmNFT;
    ArrakisPrivateVaultRouterMock public router;

    address public token0;
    address public token1;

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        w3f = vm.addr(uint256(keccak256(abi.encode("W3F"))));
        receiver = vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        // #region initialize mocks contracts.

        _creationMock();

        // #endregion initialize mocks contracts.

        token0 = address(new TokenMock("Token 0", "TKNZ"));
        token1 = usdc;

        vault.setTokens(token0, token1);

        vault.setModule(address(vault));

        // #region create selfPay.

        _createSelfPay(false);

        // #endregion create selfPay.
    }

    // #region selfPay creation.

    function _creationMock() internal {
        // #region initialize mocks contracts.

        vault = new ArrakisMetaVaultPrivateMock();
        manager = new ArrakisStandardManagerMock();
        oracle = new OracleWrapperMock();
        palmNFT = new PalmNFTMock();
        router = new ArrakisPrivateVaultRouterMock();

        // #endregion initialize mocks contracts.
    }

    function _createSelfPay(bool oracleIsInversed_) internal {
        selfPay = new SelfPay(
            owner,
            address(vault),
            address(manager),
            address(palmNFT),
            w3f,
            address(router),
            receiver,
            usdc,
            address(oracle),
            oracleIsInversed_,
            weth,
            buffer
        );
    }

    // #endregion selfPay creation.

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        owner = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorVaultAddressZero() public {
        vault = ArrakisMetaVaultPrivateMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorManagerAddressZero() public {
        manager = ArrakisStandardManagerMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorPalmNFTAddressZero() public {
        palmNFT = PalmNFTMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorW3FAddressZero() public {
        w3f = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorRouterAddressZero() public {
        router = ArrakisPrivateVaultRouterMock(address(0));

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorReceiverAddressZero() public {
        receiver = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorUSDCAddressZero() public {
        usdc = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorWETHAddressZero() public {
        weth = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);

        _createSelfPay(false);
    }

    function testConstructorCanBeSelfPay() public {
        TokenMock token0 = new TokenMock("Token 0", "TKNZ");
        TokenMock token1 = new TokenMock("Token 1", "TKNO");

        vault.setTokens(address(token0), address(token1));

        // #region create selfPay.

        vm.expectRevert(ISelfPay.CantBeSelfPay.selector);

        _createSelfPay(false);
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

    // #region test deposit.

    function testDepositOnlyOwner() public {
        address depositor =
            vm.addr(uint256(keccak256(abi.encode("Depositor"))));

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        vm.expectRevert(Ownable.Unauthorized.selector);

        selfPay.deposit(amount0, amount1);
    }

    function testDeposit() public {
        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(owner);
        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        selfPay.deposit(amount0, amount1);
        vm.stopPrank();
    }

    // #endregion test deposit.

    // #region test withdraw.

    function testWithdrawOnlyOwner() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit.

        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        selfPay.deposit(amount0, amount1);

        vm.stopPrank();

        // #endregion deposit.

        vm.expectRevert(Ownable.Unauthorized.selector);

        selfPay.withdraw(BASE, receiver);
    }

    function testWithdraw() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));
        // #region deposit.

        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        selfPay.deposit(amount0, amount1);

        // #endregion deposit.

        selfPay.withdraw(BASE, receiver);

        vm.stopPrank();
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

    // #region test setW3F.

    function testSetW3fOnlyOwner() public {
        address w3f = vm.addr(uint256(keccak256(abi.encode("W3F"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.setW3F(w3f);
    }

    function testSetW3fAddressZero() public {
        address w3f = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);
        vm.prank(owner);
        selfPay.setW3F(w3f);
    }

    function testSetW3fSame() public {
        address w3f = vm.addr(uint256(keccak256(abi.encode("W3F"))));

        vm.expectRevert(ISelfPay.SameW3F.selector);
        vm.prank(owner);
        selfPay.setW3F(w3f);
    }

    function testSetW3f() public {
        address w3f = vm.addr(uint256(keccak256(abi.encode("W3F2"))));

        vm.prank(owner);
        selfPay.setW3F(w3f);
    }

    // #endregion test setW3F.

    // #region test setRouter.

    function testSetRouterOnlyOwner() public {
        address router =
            vm.addr(uint256(keccak256(abi.encode("Router"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.setRouter(router);
    }

    function testSetRouterAddressZero() public {
        address router = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);
        vm.prank(owner);
        selfPay.setRouter(router);
    }

    function testSetRouterSame() public {
        address router =
            vm.addr(uint256(keccak256(abi.encode("Router"))));

        vm.prank(owner);
        selfPay.setRouter(router);

        vm.expectRevert(ISelfPay.SameRouter.selector);
        vm.prank(owner);
        selfPay.setRouter(router);
    }

    function testSetRouter() public {
        address router =
            vm.addr(uint256(keccak256(abi.encode("Router2"))));

        vm.prank(owner);
        selfPay.setRouter(router);
    }

    // #endregion test setRouter.

    // #region test setReceiver.

    function testSetReceiverOnlyOwner() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.setReceiver(receiver);
    }

    function testSetReceiverAddressZero() public {
        address receiver = address(0);

        vm.expectRevert(ISelfPay.AddressZero.selector);
        vm.prank(owner);
        selfPay.setReceiver(receiver);
    }

    function testSetReceiverSame() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver"))));

        vm.prank(owner);
        vm.expectRevert(ISelfPay.SameReceiver.selector);
        selfPay.setReceiver(receiver);
    }

    function testSetReceiver() public {
        address receiver =
            vm.addr(uint256(keccak256(abi.encode("Receiver2"))));

        vm.prank(owner);
        selfPay.setReceiver(receiver);
    }

    // #endregion test setReceiver.

    // #region test callRouter.

    function testCallRouterOnlyOwner() public {
        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        vm.stopPrank();

        bytes memory payload = abi.encodeWithSelector(
            ArrakisPrivateVaultRouterMock.test.selector
        );

        vm.expectRevert(Ownable.Unauthorized.selector);
        selfPay.callRouter(amount0, amount1, payload);
    }

    function testCallRouterFailingCall() public {
        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisPrivateVaultRouterMock.failTest.selector
        );

        vm.expectRevert(ISelfPay.CallFailed.selector);
        selfPay.callRouter(amount0, amount1, payload);

        vm.stopPrank();
    }

    function testCallRouter() public {
        address depositor = owner;

        uint256 amount0 = 1e18;
        uint256 amount1 = 3500e6;

        deal(token0, depositor, amount0);
        deal(token1, depositor, amount1);

        vm.startPrank(depositor);

        IERC20(token0).approve(address(selfPay), amount0);
        IERC20(token1).approve(address(selfPay), amount1);

        bytes memory payload = abi.encodeWithSelector(
            ArrakisPrivateVaultRouterMock.test.selector
        );

        selfPay.callRouter(amount0, amount1, payload);

        vm.stopPrank();
    }

    // #endregion test callRouter.

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
