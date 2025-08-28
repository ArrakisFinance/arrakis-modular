// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisMetaVaultFactory} from
    "../../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisStandardManager} from
    "../../../src/interfaces/IArrakisStandardManager.sol";
import {SetupParams} from "../../../src/structs/SManager.sol";
import {IOracleWrapper} from
    "../../../src/interfaces/IOracleWrapper.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultCreatorActor {
    IArrakisMetaVaultFactory public immutable factory;
    IArrakisStandardManager public immutable manager;

    // Track created vaults for fuzzing
    address[] public createdVaults;
    mapping(address => bool) public isVaultCreated;

    // Configuration parameters for random vault creation
    address[] public availableTokens;
    address[] public availableBeacons;
    address[] public availableOracles;

    // Counters for deterministic salt generation
    uint256 public vaultCounter;

    event VaultCreated(
        address indexed vault,
        bool isPrivate,
        address token0,
        address token1,
        address beacon
    );

    constructor(
        address factory_,
        address manager_,
        address[] memory tokens_,
        address[] memory beacons_,
        address[] memory oracles_
    ) {
        require(factory_ != address(0), "Factory address zero");
        require(manager_ != address(0), "Manager address zero");
        require(tokens_.length >= 2, "Need at least 2 tokens");
        require(beacons_.length > 0, "Need at least 1 beacon");
        require(oracles_.length > 0, "Need at least 1 oracle");

        factory = IArrakisMetaVaultFactory(factory_);
        manager = IArrakisStandardManager(manager_);
        availableTokens = tokens_;
        availableBeacons = beacons_;
        availableOracles = oracles_;
    }

    /// @notice Creates a private vault with random configuration
    /// @param seedValue Random seed for configuration selection
    /// @param owner Address that will own the vault
    /// @param moduleCreationPayload Payload for module initialization
    /// @return vault Address of the created private vault
    function createPrivateVault(
        uint256 seedValue,
        address owner,
        bytes calldata moduleCreationPayload
    ) external returns (address vault) {
        require(owner != address(0), "Owner address zero");

        // Generate deterministic but varied configurations
        bytes32 salt = keccak256(
            abi.encodePacked(vaultCounter++, seedValue, "private")
        );

        address token0;
        address token1;

        {
            // Select random tokens (ensure token0 < token1)
            uint256 token0Index = seedValue % availableTokens.length;
            uint256 token1Index =
                (seedValue + 1) % availableTokens.length;
            if (token0Index == token1Index) {
                token1Index =
                    (token1Index + 1) % availableTokens.length;
            }

            token0 = availableTokens[token0Index];
            token1 = availableTokens[token1Index];
        }

        // Select random oracle
        address oracle =
            availableOracles[seedValue % availableOracles.length];

        // Ensure proper ordering
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        // Select random beacon
        address beacon =
            availableBeacons[seedValue % availableBeacons.length];

        bytes memory initManagementPayload;

        // Create management setup params with random values
        {
            SetupParams memory setupParams =
                _generateRandomSetupParams(seedValue, owner);
            initManagementPayload = abi.encode(setupParams);
        }

        try factory.deployPrivateVault(
            salt,
            token0,
            token1,
            owner,
            beacon,
            moduleCreationPayload,
            initManagementPayload
        ) returns (address newVault) {
            vault = newVault;
            createdVaults.push(vault);
            isVaultCreated[vault] = true;

            emit VaultCreated(vault, true, token0, token1, beacon);
        } catch {
            // If deployment fails, return zero address
            vault = address(0);
        }
    }

    /// @notice Creates a public vault with random configuration
    /// @param seedValue Random seed for configuration selection
    /// @param owner Address that will own the vault
    /// @param moduleCreationPayload Payload for module initialization
    /// @return vault Address of the created public vault
    function createPublicVault(
        uint256 seedValue,
        address owner,
        bytes calldata moduleCreationPayload
    ) external returns (address vault) {
        require(owner != address(0), "Owner address zero");

        // Generate deterministic but varied configurations
        bytes32 salt = keccak256(
            abi.encodePacked(vaultCounter++, seedValue, "public")
        );

        address token0;
        address token1;

        {
            // Select random tokens (ensure token0 < token1)
            uint256 token0Index = seedValue % availableTokens.length;
            uint256 token1Index =
                (seedValue + 1) % availableTokens.length;
            if (token0Index == token1Index) {
                token1Index =
                    (token1Index + 1) % availableTokens.length;
            }

            token0 = availableTokens[token0Index];
            token1 = availableTokens[token1Index];
        }

        // Ensure proper ordering
        if (token0 > token1) {
            (token0, token1) = (token1, token0);
        }

        // Select random beacon
        address beacon =
            availableBeacons[seedValue % availableBeacons.length];

        // Create management setup params with random values
        bytes memory initManagementPayload;

        {
            SetupParams memory setupParams = _generateRandomSetupParams(seedValue, owner);
            initManagementPayload = abi.encode(setupParams);
        }

        try factory.deployPublicVault(
            salt,
            token0,
            token1,
            owner,
            beacon,
            moduleCreationPayload,
            initManagementPayload
        ) returns (address newVault) {
            vault = newVault;
            createdVaults.push(vault);
            isVaultCreated[vault] = true;

            emit VaultCreated(vault, false, token0, token1, beacon);
        } catch {
            // If deployment fails, return zero address
            vault = address(0);
        }
    }

    /// @notice Generates random setup parameters for vault management
    function _generateRandomSetupParams(
        uint256 seedValue,
        address vaultAddress
    ) internal view returns (SetupParams memory) {
        // Generate pseudo-random values within reasonable bounds
        uint256 seed1 = uint256(
            keccak256(abi.encodePacked(seedValue, block.timestamp))
        );
        uint256 seed2 =
            uint256(keccak256(abi.encodePacked(seed1, block.number)));
        uint256 seed3 =
            uint256(keccak256(abi.encodePacked(seed2, msg.sender)));

        return SetupParams({
            vault: vaultAddress,
            oracle: IOracleWrapper(
                availableOracles[seed1 % availableOracles.length]
            ),
            maxDeviation: uint24((seed2 % 1000) + 100), // 100-1099 (1-10.99%)
            cooldownPeriod: (seed3 % 3600) + 300, // 5 minutes to 1 hour
            executor: msg.sender, // Caller becomes executor for simplicity
            stratAnnouncer: msg.sender, // Caller becomes strategy announcer
            maxSlippagePIPS: uint24((seed1 % 500) + 50) // 50-549 (0.5-5.49%)
        });
    }

    /// @notice Returns all created vault addresses
    function getCreatedVaults()
        external
        view
        returns (address[] memory)
    {
        return createdVaults;
    }

    /// @notice Returns the number of created vaults
    function getCreatedVaultsCount()
        external
        view
        returns (uint256)
    {
        return createdVaults.length;
    }

    /// @notice Returns a specific created vault by index
    function getCreatedVault(
        uint256 index
    ) external view returns (address) {
        require(index < createdVaults.length, "Index out of bounds");
        return createdVaults[index];
    }

    /// @notice Updates available tokens for vault creation (for testing flexibility)
    function updateAvailableTokens(
        address[] calldata newTokens
    ) external {
        require(newTokens.length >= 2, "Need at least 2 tokens");
        availableTokens = newTokens;
    }

    /// @notice Updates available beacons for vault creation (for testing flexibility)
    function updateAvailableBeacons(
        address[] calldata newBeacons
    ) external {
        require(newBeacons.length > 0, "Need at least 1 beacon");
        availableBeacons = newBeacons;
    }

    /// @notice Updates available oracles for vault creation (for testing flexibility)
    function updateAvailableOracles(
        address[] calldata newOracles
    ) external {
        require(newOracles.length > 0, "Need at least 1 oracle");
        availableOracles = newOracles;
    }
}
