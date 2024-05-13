// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Vm} from "forge-std/Vm.sol";

import {TestWrapper} from "../../utils/TestWrapper.sol";

import {
    ArrakisMetaVaultFactory,
    IArrakisMetaVaultFactory
} from "../../../src/ArrakisMetaVaultFactory.sol";
import {CreationCodePublicVault} from
    "../../../src/CreationCodePublicVault.sol";
import {CreationCodePrivateVault} from
    "../../../src/CreationCodePrivateVault.sol";
import {IArrakisMetaVault} from
    "../../../src/interfaces/IArrakisMetaVault.sol";
import {PALMVaultNFT} from "../../../src/PALMVaultNFT.sol";
import {TimeLock} from "../../../src/TimeLock.sol";

import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {UpgradeableBeacon} from
    "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #region mocks.

import {BeaconImplementation} from "./mocks/BeaconImplementation.sol";
import {ModuleRegistryMock} from "./mocks/ModuleRegistryMock.sol";
import {ArrakisManagerMock} from "./mocks/ArrakisManagerMock.sol";
import {ArrakisManagerBuggyMock} from
    "./mocks/ArrakisManagerBuggyMock.sol";
import {ArrakisManagerBuggy2Mock} from
    "./mocks/ArrakisManagerBuggy2Mock.sol";
import {BuggyTokenA} from "./mocks/BuggyTokenA.sol";

// #endregion mocks.

contract ArrakisMetaVaultFactoryTest is TestWrapper {
    // #region constant properties.

    address public constant WETH =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    ArrakisMetaVaultFactory public factory;
    PALMVaultNFT public nft;
    address public owner;

    address public beaconAdmin;

    address public creationCodePublicVault;
    address public creationCodePrivateVault;

    // #region mock.

    ModuleRegistryMock public publicRegistry;
    ModuleRegistryMock public privateRegistry;
    ArrakisManagerMock public manager;
    address public beacon;

    // #endregion mock.

    function setUp() public {
        owner = vm.addr(uint256(keccak256(abi.encode("Owner"))));
        beaconAdmin =
            vm.addr(uint256(keccak256(abi.encode("Beacon Admin"))));

        // #region public registry.

        publicRegistry = new ModuleRegistryMock();

        // #region create a upgradeable beacon.

        address beaconAdmin =
            vm.addr(uint256(keccak256(abi.encode("Beacon Admin"))));
        BeaconImplementation implementation =
            new BeaconImplementation();

        beacon =
            address(new UpgradeableBeacon(address(implementation)));

        UpgradeableBeacon(beacon).transferOwnership(beaconAdmin);

        // #endregion create a upgradeable beacon.

        address[] memory beacons = new address[](1);
        beacons[0] = beacon;

        publicRegistry.whitelistBeacons(beacons);

        beacons = publicRegistry.beacons();

        assertEq(beacon, beacons[0]);

        // #endregion public registry.

        // #region private registries.

        privateRegistry = new ModuleRegistryMock();

        privateRegistry.whitelistBeacons(beacons);

        beacons = privateRegistry.beacons();

        assertEq(beacon, beacons[0]);

        // #endregion private registries.

        // #region manager.

        manager = new ArrakisManagerMock();

        // #endregion manager.

        // #region creation code contracts.

        creationCodePublicVault =
            address(new CreationCodePublicVault());
        creationCodePrivateVault =
            address(new CreationCodePrivateVault());

        // #endregion creation code contracts.

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(manager),
            address(publicRegistry),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );

        nft = factory.nft();
    }

    // #region test constructor.

    function testConstructorOwnerAddressZero() public {
        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory = new ArrakisMetaVaultFactory(
            address(0),
            address(manager),
            address(publicRegistry),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );
    }

    function testConstructorManagerAddressZero() public {
        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(0),
            address(publicRegistry),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );
    }

    function testConstructorPublicRegistryAddressZero() public {
        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(manager),
            address(0),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );
    }

    function testConstructorPrivateRegistryAddressZero() public {
        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(manager),
            address(publicRegistry),
            address(0),
            creationCodePublicVault,
            creationCodePrivateVault
        );
    }

    // #endregion test constructor.

    // #region test paused/unpaused.

    function testPausedOnlyOwner() public {
        address caller = vm.addr(111);

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        factory.pause();
    }

    function testPause() public {
        assertEq(factory.paused(), false);

        factory.pause();

        assertEq(factory.paused(), true);
    }

    function testPauseWhenAlreadyPaused() public {
        // #region pause factory.
        assertEq(factory.paused(), false);
        factory.pause();
        assertEq(factory.paused(), true);
        // #endregion pause factory.

        vm.expectRevert(bytes("Pausable: paused"));

        factory.pause();
    }

    function testUnPauseOnlyOwner() public {
        factory.pause();
        address caller = vm.addr(111);

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        factory.unpause();
    }

    function testUnPauseNotPaused() public {
        assertEq(factory.paused(), false);

        vm.expectRevert(bytes("Pausable: not paused"));
        factory.unpause();
    }

    function testUnPause() public {
        assertEq(factory.paused(), false);

        factory.pause();

        assertEq(factory.paused(), true);

        factory.unpause();

        assertEq(factory.paused(), false);
    }

    // #endregion test paused/unpaused.

    // #region test setManager.

    function testSetManagerOnlyOwner() public {
        address newManager =
            vm.addr(uint256(keccak256(abi.encode("New Manager"))));
        address caller =
            vm.addr(uint256(keccak256(abi.encode("Caller"))));

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(caller);

        factory.setManager(newManager);
    }

    function testSetManagerAddressZero() public {
        address newManager = address(0);

        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory.setManager(newManager);
    }

    function testSetManagerSameManager() public {
        vm.expectRevert(IArrakisMetaVaultFactory.SameManager.selector);

        factory.setManager(address(manager));
    }

    function testSetManager() public {
        address newManager =
            vm.addr(uint256(keccak256(abi.encode("New Manager"))));

        address currentManager = factory.manager();
        assertEq(currentManager, address(manager));

        factory.setManager(newManager);

        currentManager = factory.manager();

        assertEq(currentManager, newManager);
    }

    // #endregion test setManager.

    // #region create private vault.

    function testDeployPrivateVault() public {
        bytes32 privateSalt =
            keccak256(abi.encode("Test private vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPrivateVault(
                privateSalt, USDC, WETH, owner, beacon, payload, ""
            )
        );

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assert(address(vault) != address(0));
        assert(address(vault.module()) != address(0));
        assertEq(nft.ownerOf(uint256(uint160(address(vault)))), owner);
    }

    // #endregion create private vault.

    // #region create public vault.

    function testDeployPublicVaultOnlyDeployer() public {
        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        vm.expectRevert(
            IArrakisMetaVaultFactory.NotADeployer.selector
        );

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, USDC, WETH, owner, beacon, payload, ""
            )
        );
    }

    function testDeployPublicVault() public {
        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        vm.prank(deployer1);

        vm.recordLogs();

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, USDC, WETH, owner, beacon, payload, ""
            )
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assert(address(vault) != address(0));
        assert(address(vault.module()) != address(0));

        (,,,,,, address timeLock) = abi.decode(
            entries[entries.length - 1].data,
            (
                bytes32,
                address,
                address,
                address,
                address,
                address,
                address
            )
        );

        assertEq(Ownable(address(vault)).owner(), timeLock);
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("TIMELOCK_ADMIN_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("PROPOSER_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("EXECUTOR_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("CANCELLER_ROLE"), owner
            )
        );
    }

    function testDeployPublicVaultWithBuggyTokenA() public {
        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        // #region token0 buggy in function name.

        BuggyTokenA tokenA = new BuggyTokenA();

        (address token0, address token1) = address(tokenA) > USDC
            ? (USDC, address(tokenA))
            : (address(tokenA), USDC);

        // #endregion token0 buggy in funtion name.

        vm.prank(deployer1);

        vm.recordLogs();

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, token0, token1, owner, beacon, payload, ""
            )
        );

        Vm.Log[] memory entries = vm.getRecordedLogs();

        assertEq(vault.token0(), token0);
        assertEq(vault.token1(), token1);
        assert(address(vault) != address(0));
        assert(address(vault.module()) != address(0));

        (,,,,,, address timeLock) = abi.decode(
            entries[entries.length - 1].data,
            (
                bytes32,
                address,
                address,
                address,
                address,
                address,
                address
            )
        );

        assertEq(Ownable(address(vault)).owner(), timeLock);
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("TIMELOCK_ADMIN_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("PROPOSER_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("EXECUTOR_ROLE"), owner
            )
        );
        assertTrue(
            TimeLock(payable(timeLock)).hasRole(
                keccak256("CANCELLER_ROLE"), owner
            )
        );
    }

    function testDeployPublicVaultCallFailed() public {
        ArrakisManagerBuggyMock m = new ArrakisManagerBuggyMock();

        // #region create factory.

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(m),
            address(publicRegistry),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );

        nft = factory.nft();

        // #endregion create factory.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        // #region token0 buggy in function name.

        BuggyTokenA tokenA = new BuggyTokenA();

        (address token0, address token1) = address(tokenA) > USDC
            ? (USDC, address(tokenA))
            : (address(tokenA), USDC);

        // #endregion token0 buggy in funtion name.

        vm.prank(deployer1);

        vm.expectRevert(IArrakisMetaVaultFactory.CallFailed.selector);

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, token0, token1, owner, beacon, payload, ""
            )
        );
    }

    function testDeployPublicVaultVaultNotManaged() public {
        ArrakisManagerBuggy2Mock m = new ArrakisManagerBuggy2Mock();

        // #region create factory.

        factory = new ArrakisMetaVaultFactory(
            address(this),
            address(m),
            address(publicRegistry),
            address(privateRegistry),
            creationCodePublicVault,
            creationCodePrivateVault
        );

        nft = factory.nft();

        // #endregion create factory.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        // #region token0 buggy in function name.

        BuggyTokenA tokenA = new BuggyTokenA();

        (address token0, address token1) = address(tokenA) > USDC
            ? (USDC, address(tokenA))
            : (address(tokenA), USDC);

        // #endregion token0 buggy in funtion name.

        vm.prank(deployer1);

        vm.expectRevert(
            IArrakisMetaVaultFactory.VaultNotManaged.selector
        );

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, token0, token1, owner, beacon, payload, ""
            )
        );
    }

    // #endregion create public vault.

    // #region whitelist public vault deployers.

    function testWhitelistDeployerOnlyOwner() public {
        // #region deployers to whitelist.

        address[] memory deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        // #endregion deployers to whitelist.

        address anotherOwner =
            vm.addr(uint256(keccak256(abi.encode("Another Owner"))));

        vm.prank(anotherOwner);
        vm.expectRevert(Ownable.Unauthorized.selector);

        factory.whitelistDeployer(deployers);
    }

    function testWhitelistDeployerAddressZero() public {
        // #region deployers to whitelist.

        address[] memory deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));

        // #endregion deployers to whitelist.

        address anotherOwner =
            vm.addr(uint256(keccak256(abi.encode("Another Owner"))));

        vm.expectRevert(IArrakisMetaVaultFactory.AddressZero.selector);

        factory.whitelistDeployer(deployers);
    }

    function testWhitelistDeployerAlreadyWhitelisted() public {
        address[] memory deployers = new address[](1);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        factory.whitelistDeployer(deployers);

        // #region deployers to whitelist.

        deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        // #endregion deployers to whitelist.

        address anotherOwner =
            vm.addr(uint256(keccak256(abi.encode("Another Owner"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory
                    .AlreadyWhitelistedDeployer
                    .selector,
                deployers[0]
            )
        );

        factory.whitelistDeployer(deployers);
    }

    function testWhitelistDeployer() public {
        // #region deployers to whitelist.

        address[] memory deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        // #endregion deployers to whitelist.

        factory.whitelistDeployer(deployers);

        // #region checks.

        address[] memory actualDeployers = factory.deployers();

        assertEq(deployers[0], actualDeployers[0]);
        assertEq(deployers[1], actualDeployers[1]);

        // #endregion checks.
    }

    // #endregion whitelist public vault deployers.

    // #region blacklist public vault deployers.

    function testBlacklistDeployerOnlyOwner() public {
        // #region whitelist deployers.

        address[] memory deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployers.

        address anotherOwner =
            vm.addr(uint256(keccak256(abi.encode("Another Owner"))));

        vm.prank(anotherOwner);
        vm.expectRevert(Ownable.Unauthorized.selector);

        factory.blacklistDeployer(deployers);
    }

    function testBlacklistDeployerNotAlreadyADeployer() public {
        // #region whitelist deployers.

        address[] memory deployers = new address[](1);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployers.

        deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory.NotAlreadyADeployer.selector,
                deployers[1]
            )
        );

        factory.blacklistDeployer(deployers);
    }

    function testBlacklistDeployer() public {
        // #region whitelist deployers.

        address[] memory deployers = new address[](2);
        deployers[0] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        deployers[1] =
            vm.addr(uint256(keccak256(abi.encode("Deployer 2"))));

        factory.whitelistDeployer(deployers);

        address[] memory actualDeployers = factory.deployers();

        assertEq(deployers[0], actualDeployers[0]);
        assertEq(deployers[1], actualDeployers[1]);

        // #endregion whitelist deployers.

        factory.blacklistDeployer(deployers);

        actualDeployers = factory.deployers();

        assert(actualDeployers.length == 0);
    }

    // #endregion blacklist public vault deployers.

    // #region test get token name.

    function testGetTokenName() public {
        string memory vaultName = factory.getTokenName(USDC, WETH);

        assertEq(
            string(
                abi.encodePacked(
                    "Arrakis Modular ",
                    IERC20Metadata(USDC).symbol(),
                    "/",
                    IERC20Metadata(WETH).symbol()
                )
            ),
            vaultName
        );
    }

    // #endregion test get token name.

    // #region test get token symbol.

    function testGetTokenSymbol() public {
        string memory vaultSymbol = factory.getTokenSymbol(USDC, WETH);

        assertEq(
            string(
                abi.encodePacked(
                    "AM",
                    "/",
                    IERC20Metadata(USDC).symbol(),
                    "/",
                    IERC20Metadata(WETH).symbol()
                )
            ),
            vaultSymbol
        );
    }

    // #endregion test get token symbol.

    // #region test publicVaults.

    function testPublicVaultStartIndexLtEndIndex() public {
        uint256 startIndex = 10;
        uint256 endIndex = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory.StartIndexLtEndIndex.selector,
                startIndex,
                endIndex
            )
        );

        factory.publicVaults(startIndex, endIndex);
    }

    function testPublicVaultEndIndexGtNbOfVaults() public {
        // #region create public vault.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        vm.prank(deployer1);

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(
                publicSalt, USDC, WETH, owner, beacon, payload, ""
            )
        );

        // #endregion create public vault.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory.EndIndexGtNbOfVaults.selector,
                endIndex,
                factory.numOfPublicVaults()
            )
        );

        factory.publicVaults(startIndex, endIndex);
    }

    function testPublicVaults() public {
        // #region create a public vaults.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        vm.prank(deployer1);

        address vault0 = factory.deployPublicVault(
            publicSalt, USDC, WETH, owner, beacon, payload, ""
        );

        publicSalt = keccak256(abi.encode("Test public vault 2"));

        vm.prank(deployer1);

        address vault1 = factory.deployPublicVault(
            publicSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a public vaults.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        address[] memory vaults =
            factory.publicVaults(startIndex, endIndex);

        assertEq(vaults[0], vault0);
        assertEq(vaults[1], vault1);
    }

    // #endregion test publicVaults.

    // #region test numOfPublicVaults.

    function testNumOfPublicVaults() public {
        assertEq(factory.numOfPublicVaults(), 0);

        // #region create a public vaults.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        vm.prank(deployer1);

        factory.deployPublicVault(
            publicSalt, USDC, WETH, owner, beacon, payload, ""
        );

        publicSalt = keccak256(abi.encode("Test public vault 2"));

        vm.prank(deployer1);

        factory.deployPublicVault(
            publicSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a public vaults.

        assertEq(factory.numOfPublicVaults(), 2);
    }

    // #endregion test numOfPublicVaults.

    // #region test isPublicVault.

    function testIsPublicVaultFalse() public {
        address notAPublicVault = vm.addr(
            uint256(keccak256(abi.encode("Not a public vault")))
        );

        bool isPublicVault = factory.isPublicVault(notAPublicVault);

        assertEq(isPublicVault, false);
    }

    function testIsPublicVaultTrue() public {
        // #region create a public vaults.

        bytes32 publicSalt =
            keccak256(abi.encode("Test public vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        // #region whitelist deployer.
        address deployer1 =
            vm.addr(uint256(keccak256(abi.encode("Deployer 1"))));
        address[] memory deployers = new address[](1);
        deployers[0] = deployer1;

        factory.whitelistDeployer(deployers);

        // #endregion whitelist deployer.

        vm.prank(deployer1);

        address vault = factory.deployPublicVault(
            publicSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a public vaults.

        bool isPublicVault = factory.isPublicVault(vault);

        assertEq(isPublicVault, true);
    }

    // #endregion test isPublicVault.

    // #region test privateVaults.

    function testPrivateVaultStartIndexLtEndIndex() public {
        uint256 startIndex = 10;
        uint256 endIndex = 0;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory.StartIndexLtEndIndex.selector,
                startIndex,
                endIndex
            )
        );

        factory.privateVaults(startIndex, endIndex);
    }

    function testPrivateVaultEndIndexGtNbOfVaults() public {
        // #region create a private vault.

        bytes32 privateSalt =
            keccak256(abi.encode("Test private vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a private vault.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        vm.expectRevert(
            abi.encodeWithSelector(
                IArrakisMetaVaultFactory.EndIndexGtNbOfVaults.selector,
                endIndex,
                factory.numOfPrivateVaults()
            )
        );

        factory.privateVaults(startIndex, endIndex);
    }

    function testPrivateVaults() public {
        // #region create a private vault.

        bytes32 privateSalt =
            keccak256(abi.encode("Test private vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        address vault0 = factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        privateSalt = keccak256(abi.encode("Test private vault 2"));

        address vault1 = factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a private vault.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        address[] memory vaults =
            factory.privateVaults(startIndex, endIndex);

        assertEq(vaults[0], vault0);
        assertEq(vaults[1], vault1);
    }

    // #endregion test privateVaults.

    // #region test numOfPrivateVaults.

    function testNumOfPrivateVaults() public {
        assertEq(factory.numOfPrivateVaults(), 0);

        // #region create a private vault.

        bytes32 privateSalt =
            keccak256(abi.encode("Test private vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        address vault0 = factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        privateSalt = keccak256(abi.encode("Test private vault 2"));

        address vault1 = factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create a private vault.

        assertEq(factory.numOfPrivateVaults(), 2);
    }

    // #endregion test numOfPrivateVaults.

    // #region test isPrivateVault.

    function testIsPrivateVaultFalse() public {
        address notAPrivateVault = vm.addr(
            uint256(keccak256(abi.encode("Not a private vault")))
        );

        bool isPrivateVault = factory.isPrivateVault(notAPrivateVault);

        assertEq(isPrivateVault, false);
    }

    function testIsPrivateVaultTrue() public {
        // #region create private vault.

        bytes32 privateSalt =
            keccak256(abi.encode("Test private vault"));
        address pauser =
            vm.addr(uint256(keccak256(abi.encode("Pauser"))));

        // #region create module payload.

        bytes memory payload = abi.encodeWithSelector(
            BeaconImplementation.setGuardianAndMetaVault.selector,
            pauser
        );

        // #endregion create module payload.

        address vault = factory.deployPrivateVault(
            privateSalt, USDC, WETH, owner, beacon, payload, ""
        );

        // #endregion create private vault.

        bool isPrivateVault = factory.isPrivateVault(vault);

        assertEq(isPrivateVault, true);
    }

    // #endregion test isPrivateVault.
}
