// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisStandardManager} from
    "../../src/ArrakisStandardManager.sol";
import {NATIVE_COIN} from "../../src/constants/CArrakis.sol";

import {
    ProxyAdmin,
    Ownable
} from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";
import {
    ITransparentUpgradeableProxy,
    TransparentUpgradeableProxy
} from
    "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

// Implementation : 0xC618797D1Fd0283d535753aDa6a6AA24Fce2e745
// Proxy : 0x2e6E879648293e939aA68bA4c6c129A1Be733bDA
contract DArrakisStandardManager is CreateXScript {
    // #region constants.

    uint88 public constant implVersion = uint88(
        uint256(
            keccak256(
                abi.encode("Arrakis Standard Manager Impl version 1")
            )
        )
    );

    uint88 public constant proxyAdminVersion = uint88(
        uint256(keccak256(abi.encode("Proxy Admin version 1")))
    );

    uint88 public constant proxyVersion =
        uint88(uint256(keccak256(abi.encode("Proxy version 1"))));

    address constant guardian =
        0x6F441151B478E0d60588f221f1A35BcC3f7aB981;
    address constant arrakisTimeLock =
        0xAf6f9640092cB1236E5DB6E517576355b6C40b7f;

    uint256 constant defaultFeePIPS = 10_000; // 1%
    uint8 constant nativeCoinDecimals = 18;

    // #endregion constants.

    address public deployer;

    function setUp() public {}

    function run() public {
        address proxyAdmin = ArrakisRoles.getAdmin();

        vm.startBroadcast();

        console.logString("Deployer :");
        console.logAddress(msg.sender);

        address implementation =
            _deployArrakisStandardManagerImpl(guardian);
        address proxy =
            _deployTransparentProxy(implementation, proxyAdmin);

        vm.stopBroadcast();

        // #region test a update.

        // implementation = _deployTestArrakisStandardManagerImpl(guardian);
        // console.logString("New implementation : ");
        // console.logAddress(implementation);

        // bytes memory updateData = abi.encodeWithSelector(ITransparentUpgradeableProxy.upgradeTo.selector, implementation);

        // vm.prank(proxyAdmin);
        // proxy.call(updateData);

        // console.logString("New Address : ");
        // vm.prank(proxyAdmin);
        // console.logAddress(ITransparentUpgradeableProxy(proxy).implementation());

        // #endregion test a update.
    }

    function _deployArrakisStandardManagerImpl(
        address guardian_
    ) internal returns (address implementation) {
        bytes memory initCode = abi.encodePacked(
            type(ArrakisStandardManager).creationCode,
            abi.encode(
                defaultFeePIPS,
                NATIVE_COIN,
                nativeCoinDecimals,
                guardian_
            )
        );

        bytes32 salt = bytes32(
            abi.encodePacked(
                msg.sender, hex"00", bytes11(implVersion)
            )
        );

        implementation = computeCreate3Address(salt, msg.sender);

        console.logString(
            "Arrakis Standard Manager Implementation Address : "
        );
        console.logAddress(implementation);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString(
            "Simulation Arrakis Standard Manager Implementation Address :"
        );
        console.logAddress(actualAddr);

        if (actualAddr != implementation) {
            revert("Create 3 addresses don't match.");
        }
    }

    function _deployTransparentProxy(
        address implementation_,
        address proxyAdmin_
    ) internal returns (address proxy) {
        bytes memory initCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(implementation_, proxyAdmin_, "")
        );

        bytes32 salt = bytes32(
            abi.encodePacked(
                msg.sender, hex"00", bytes11(proxyVersion)
            )
        );

        proxy = computeCreate3Address(salt, msg.sender);

        console.logString("Transparent Proxy Address : ");
        console.logAddress(proxy);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Transparent Proxy Address :");
        console.logAddress(actualAddr);

        if (actualAddr != proxy) {
            revert("Create 3 addresses don't match.");
        }
    }
}
