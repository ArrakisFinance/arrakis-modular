// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";

import {CreateXScript} from "./CreateXScript.sol";
import {ICreateX} from "./interfaces/ICreateX.sol";
import {ArrakisRoles} from "./constants/ArrakisRoles.sol";

import {ArrakisMetaVaultFactory} from
    "../../src/ArrakisMetaVaultFactory.sol";

// Factory : 0x820FB8127a689327C863de8433278d6181123982
// PrivateVaultNFT : 0x44A801e7E2E073bd8bcE4bCCf653239Fa156B762
// Renderer Controller : 0x1Cc0Adff599F244f036a5C2425f646Aef884149D
contract DFactory is CreateXScript {
    uint88 public version =
        uint88(uint256(keccak256(abi.encode("Factory version 1"))));

    address public constant manager =
        0x2e6E879648293e939aA68bA4c6c129A1Be733bDA;
    address public constant publicRegistry =
        0x791d75F87a701C3F7dFfcEC1B6094dB22c779603;
    address public constant privateRegistry =
        0xe278C1944BA3321C1079aBF94961E9fF1127A265;
    address public constant creationCodePublicVault =
        0x374BCFff317203B5fab2c266b4a876d47E109331;
    address public constant creationCodePrivateVault =
        0x69e58f06c4FB059E3F94Af3EB4DF64c57fdAb00f;

    function setUp() public {}

    function run() public {
        uint256 privateKey = vm.envUint("PK_TEST");

        address deployer = vm.addr(privateKey);

        address owner = ArrakisRoles.getOwner();

        console.logString("Deployer :");
        console.logAddress(deployer);

        vm.startBroadcast(privateKey);

        bytes memory initCode = abi.encodePacked(
            type(ArrakisMetaVaultFactory).creationCode,
            abi.encode(
                owner,
                manager,
                publicRegistry,
                privateRegistry,
                creationCodePublicVault,
                creationCodePrivateVault
            )
        );

        bytes32 salt = bytes32(
            abi.encodePacked(deployer, hex"00", bytes11(version))
        );

        address factory = computeCreate3Address(salt, deployer);

        console.logString("Factory Address : ");
        console.logAddress(factory);

        address actualAddr = CreateX.deployCreate3(salt, initCode);

        console.logString("Simulation Address :");
        console.logAddress(actualAddr);

        if (factory != actualAddr) {
            revert("Create 3 addresses don't match.");
        }

        vm.stopBroadcast();
    }
}
