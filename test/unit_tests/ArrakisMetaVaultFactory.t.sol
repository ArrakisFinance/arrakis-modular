// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {console} from "forge-std/console.sol";

import {TestWrapper} from "../utils/TestWrapper.sol";

import {ArrakisMetaVaultFactory, IArrakisMetaVaultFactory} from "../../src/ArrakisMetaVaultFactory.sol";
import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract ArrakisMetaVaultFactoryTest is TestWrapper {
    // #region constant properties.

    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    // #endregion constant properties.

    ArrakisMetaVaultFactory public factory;
    address public owner;
    address public module;

    function setUp() public {
        owner = vm.addr(1);
        module = vm.addr(12);

        factory = new ArrakisMetaVaultFactory(address(this));
    }

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

    function testUnPauseOnlyOwner() public {
        factory.pause();
        address caller = vm.addr(111);

        vm.prank(caller);
        vm.expectRevert(Ownable.Unauthorized.selector);

        factory.unpause();
    }

    function testUnPauseNotPaused() public {
        assertEq(factory.paused(), false);

        vm.expectRevert(Pausable.ExpectedPause.selector);
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

    // #region create private vault.

    function testDeployPrivateVault() public {
        bytes32 privateSalt = keccak256(abi.encode("Test private vault"));

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assertEq(address(vault.module()), module);
        assertEq(Ownable(address(vault)).owner(), owner);

        assert(address(vault) != address(0));
    }

    // #endregion create private vault.

    // #region create public vault.

    function testDeployPublicVault() public {
        bytes32 publicSalt = keccak256(abi.encode("Test public vault"));

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assertEq(address(vault.module()), module);
        assertEq(Ownable(address(vault)).owner(), owner);

        assert(address(vault) != address(0));
    }

    // #endregion create public vault.

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
        // #region create a public vault.

        bytes32 publicSalt = keccak256(abi.encode("Test public vault"));

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assertEq(address(vault.module()), module);
        assertEq(Ownable(address(vault)).owner(), owner);

        assert(address(vault) != address(0));

        // #endregion create a public vault.

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

        bytes32 publicSalt = keccak256(abi.encode("Test public vault 0"));

        IArrakisMetaVault vault0 = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault0.token0(), USDC);
        assertEq(vault0.token1(), WETH);
        assertEq(address(vault0.module()), module);
        assertEq(Ownable(address(vault0)).owner(), owner);
        assert(address(vault0) != address(0));

        publicSalt = keccak256(abi.encode("Test public vault 1"));

        IArrakisMetaVault vault1 = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault1.token0(), USDC);
        assertEq(vault1.token1(), WETH);
        assertEq(address(vault1.module()), module);
        assertEq(Ownable(address(vault1)).owner(), owner);
        assert(address(vault1) != address(0));

        assert(address(vault0) != address(vault1));

        // #endregion create a public vaults.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        address[] memory vaults = factory.publicVaults(startIndex, endIndex);

        assertEq(vaults[0], address(vault0));
        assertEq(vaults[1], address(vault1));
    }

    // #endregion test publicVaults.

    // #region test numOfPublicVaults.

    function testNumOfPublicVaults() public {
        assertEq(factory.numOfPublicVaults(), 0);

        // #region create a public vaults.

        bytes32 publicSalt = keccak256(abi.encode("Test public vault 0"));

        IArrakisMetaVault vault0 = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault0.token0(), USDC);
        assertEq(vault0.token1(), WETH);
        assertEq(address(vault0.module()), module);
        assertEq(Ownable(address(vault0)).owner(), owner);
        assert(address(vault0) != address(0));

        publicSalt = keccak256(abi.encode("Test public vault 1"));

        IArrakisMetaVault vault1 = IArrakisMetaVault(
            factory.deployPublicVault(publicSalt, USDC, WETH, owner, module)
        );

        assertEq(vault1.token0(), USDC);
        assertEq(vault1.token1(), WETH);
        assertEq(address(vault1.module()), module);
        assertEq(Ownable(address(vault1)).owner(), owner);
        assert(address(vault1) != address(0));

        assert(address(vault0) != address(vault1));

        // #endregion create a public vaults.

        assertEq(factory.numOfPublicVaults(), 2);
    }

    // #endregion test numOfPublicVaults.

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

        bytes32 privateSalt = keccak256(abi.encode("Test private vault"));

        IArrakisMetaVault vault = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault.token0(), USDC);
        assertEq(vault.token1(), WETH);
        assertEq(address(vault.module()), module);
        assertEq(Ownable(address(vault)).owner(), owner);

        assert(address(vault) != address(0));

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
        // #region create a private vaults.

        bytes32 privateSalt = keccak256(abi.encode("Test private vault 0"));

        IArrakisMetaVault vault0 = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault0.token0(), USDC);
        assertEq(vault0.token1(), WETH);
        assertEq(address(vault0.module()), module);
        assertEq(Ownable(address(vault0)).owner(), owner);
        assert(address(vault0) != address(0));

        privateSalt = keccak256(abi.encode("Test private vault 1"));

        IArrakisMetaVault vault1 = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault1.token0(), USDC);
        assertEq(vault1.token1(), WETH);
        assertEq(address(vault1.module()), module);
        assertEq(Ownable(address(vault1)).owner(), owner);
        assert(address(vault1) != address(0));

        assert(address(vault0) != address(vault1));

        // #endregion create a private vaults.

        uint256 startIndex = 0;
        uint256 endIndex = 2;

        address[] memory vaults = factory.privateVaults(startIndex, endIndex);

        assertEq(vaults[0], address(vault0));
        assertEq(vaults[1], address(vault1));
    }

    // #endregion test privateVaults.


    // #region test numOfPrivateVaults.

    function testNumOfPrivateVaults() public {
        assertEq(factory.numOfPrivateVaults(), 0);

        // #region create a private vaults.

        bytes32 privateSalt = keccak256(abi.encode("Test private vault 0"));

        IArrakisMetaVault vault0 = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault0.token0(), USDC);
        assertEq(vault0.token1(), WETH);
        assertEq(address(vault0.module()), module);
        assertEq(Ownable(address(vault0)).owner(), owner);
        assert(address(vault0) != address(0));

        privateSalt = keccak256(abi.encode("Test private vault 1"));

        IArrakisMetaVault vault1 = IArrakisMetaVault(
            factory.deployPrivateVault(privateSalt, USDC, WETH, owner, module)
        );

        assertEq(vault1.token0(), USDC);
        assertEq(vault1.token1(), WETH);
        assertEq(address(vault1.module()), module);
        assertEq(Ownable(address(vault1)).owner(), owner);
        assert(address(vault1) != address(0));

        assert(address(vault0) != address(vault1));

        // #endregion create a private vaults.

        assertEq(factory.numOfPrivateVaults(), 2);
    }

    // #endregion test numOfPrivateVaults.


}
