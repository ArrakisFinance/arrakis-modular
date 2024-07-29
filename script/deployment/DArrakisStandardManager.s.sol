// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";
import {CREATEX_ADDRESS} from "./constants/CCreateX.sol";

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
        0x3Cc5ceaFc3F68D79937fC87582a6343d2Fa2C4a5;
    address constant arrakisTimeLock =
        0x9FE545267089DCa885aA9DB2287eEe0B829CC1E7;

    uint256 constant defaultFeePIPS = 10_000; // 1%
    uint8 constant nativeCoinDecimals = 18;

    // #endregion constants.

    address public deployer;

    function setUp() public {}

    function run() public {
        // owner multisig can do the deploymenet.
        // owner will also be the owner of guardian.
        deployer = ArrakisRoles.getOwner();

        address proxyAdmin = ArrakisRoles.getAdmin();

        console.logString("Deployer :");
        console.logAddress(deployer);

        address implementation =
            _deployArrakisStandardManagerImpl(guardian);
        address proxy =
            _deployTransparentProxy(implementation, proxyAdmin);

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

    function _deployArrakisStandardManagerImpl(address guardian_)
        internal
        returns (address implementation)
    {
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
            abi.encodePacked(deployer, hex"00", bytes11(implVersion))
        );

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        implementation = computeCreate3Address(salt, deployer);

        console.logString(
            "Arrakis Standard Manager Implementation Address : "
        );
        console.logAddress(implementation);

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
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
            abi.encodePacked(deployer, hex"00", bytes11(proxyVersion))
        );

        bytes memory payload = abi.encodeWithSelector(
            ICreateX.deployCreate3.selector, salt, initCode
        );

        console.logString("Payload :");
        console.logBytes(payload);
        console.logString("Send to :");
        console.logAddress(CREATEX_ADDRESS);

        proxy = computeCreate3Address(salt, deployer);

        console.logString("Transparent Proxy Address : ");
        console.logAddress(proxy);

        vm.prank(deployer);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Transparent Proxy Address :");
        console.logAddress(actualAddr);

        if (actualAddr != proxy) {
            revert("Create 3 addresses don't match.");
        }
    }

    function _deployTestArrakisStandardManagerImpl(address guardian_)
        internal
        returns (address implementation)
    {
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
                deployer, hex"00", bytes11(implVersion + 1)
            )
        );

        vm.prank(deployer);

        implementation = CreateX.deployCreate3(salt, initCode);
    }
}
