// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisStandardManager} from "../../../src/interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVault} from "../../../src/interfaces/IArrakisMetaVault.sol";
import {IPancakeSwapV3StandardModule} from "../../../src/interfaces/IPancakeSwapV3StandardModule.sol";
import {RebalanceParams} from "../../../src/structs/SPancakeSwapV3.sol";
import {ModifyPosition, SwapPayload} from "../../../src/structs/SUniswapV3.sol";
import {INonfungiblePositionManagerPancake} from "../../../src/interfaces/INonfungiblePositionManagerPancake.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ExecutorActor {
    IArrakisStandardManager public immutable manager;
    
    // Track rebalance operations for analysis
    struct RebalanceLog {
        address vault;
        uint256 timestamp;
        uint256 payloadsCount;
        bool success;
    }
    
    RebalanceLog[] public rebalanceHistory;
    mapping(address => uint256) public vaultRebalanceCount;
    
    // Random operation generators
    uint256 public nonce;
    
    event RebalanceExecuted(
        address indexed vault,
        uint256 payloadsCount,
        bool success
    );
    
    event RebalanceFailed(
        address indexed vault,
        string reason
    );
    
    constructor(address manager_) {
        require(manager_ != address(0), "Manager address zero");
        manager = IArrakisStandardManager(manager_);
    }
    
    /// @notice Executes a random rebalance operation on a vault
    /// @param vault The vault to rebalance
    /// @param seedValue Random seed for generating rebalance parameters
    /// @param enableSwap Whether to include swap operations
    /// @param enablePositionChanges Whether to modify existing positions
    /// @param enableNewPositions Whether to create new positions
    function executeRandomRebalance(
        address vault,
        uint256 seedValue,
        bool enableSwap,
        bool enablePositionChanges,
        bool enableNewPositions
    ) external {
        require(vault != address(0), "Vault address zero");
        
        // Generate random rebalance payload
        bytes[] memory payloads = _generateRandomRebalancePayloads(
            vault,
            seedValue,
            enableSwap,
            enablePositionChanges,
            enableNewPositions
        );
        
        try manager.rebalance(vault, payloads) {
            // Success
            _logRebalance(vault, payloads.length, true);
            emit RebalanceExecuted(vault, payloads.length, true);
        } catch Error(string memory reason) {
            // Rebalance failed with reason
            _logRebalance(vault, payloads.length, false);
            emit RebalanceFailed(vault, reason);
        } catch {
            // Rebalance failed without reason
            _logRebalance(vault, payloads.length, false);
            emit RebalanceFailed(vault, "Unknown error");
        }
    }
    
    /// @notice Executes a simple rebalance with minimal parameters
    /// @param vault The vault to rebalance
    /// @param seedValue Random seed for basic parameter generation
    function executeSimpleRebalance(address vault, uint256 seedValue) external {
        require(vault != address(0), "Vault address zero");
        
        // Create simple rebalance with just burn/mint operations
        bytes[] memory payloads = new bytes[](1);
        
        RebalanceParams memory params = _generateSimpleRebalanceParams(vault, seedValue);
        payloads[0] = abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.rebalance.selector,
            params
        );
        
        try manager.rebalance(vault, payloads) {
            _logRebalance(vault, payloads.length, true);
            emit RebalanceExecuted(vault, payloads.length, true);
        } catch Error(string memory reason) {
            _logRebalance(vault, payloads.length, false);
            emit RebalanceFailed(vault, reason);
        } catch {
            _logRebalance(vault, payloads.length, false);
            emit RebalanceFailed(vault, "Unknown error");
        }
    }
    
    /// @notice Sets a new module for a vault (strategy change)
    /// @param vault The vault to update
    /// @param newModule The new module address
    /// @param initPayloads Payloads for initializing the new module
    function setVaultModule(
        address vault,
        address newModule,
        bytes[] calldata initPayloads
    ) external {
        require(vault != address(0), "Vault address zero");
        require(newModule != address(0), "Module address zero");
        
        try manager.setModule(vault, newModule, initPayloads) {
            // Module change successful
        } catch Error(string memory reason) {
            emit RebalanceFailed(vault, reason);
        } catch {
            emit RebalanceFailed(vault, "Module change failed");
        }
    }
    
    /// @notice Generates random rebalance payloads
    function _generateRandomRebalancePayloads(
        address vault,
        uint256 seedValue,
        bool enableSwap,
        bool enablePositionChanges,
        bool enableNewPositions
    ) internal returns (bytes[] memory) {
        uint256 seed = _generateSeed(seedValue);
        
        // Determine number of payloads (1-3)
        uint256 payloadCount = (seed % 3) + 1;
        bytes[] memory payloads = new bytes[](payloadCount);
        
        for (uint256 i = 0; i < payloadCount; i++) {
            uint256 operation = (_generateSeed(seed + i) % 4);
            
            if (operation == 0) {
                // Simple rebalance
                payloads[i] = _createRebalancePayload(
                    vault,
                    seed + i,
                    enableSwap,
                    enablePositionChanges,
                    enableNewPositions
                );
            } else if (operation == 1) {
                // Withdraw manager balance
                payloads[i] = abi.encodeWithSelector(
                    IPancakeSwapV3StandardModule.withdrawManagerBalance.selector
                );
            } else if (operation == 2) {
                // Claim manager rewards
                payloads[i] = abi.encodeWithSelector(
                    IPancakeSwapV3StandardModule.claimManager.selector
                );
            } else {
                // Set manager fee (random fee between 0-1000 PIPS)
                uint256 newFee = (_generateSeed(seed + i) % 1001);
                payloads[i] = abi.encodeWithSelector(
                    IPancakeSwapV3StandardModule.setManagerFeePIPS.selector,
                    newFee
                );
            }
        }
        
        return payloads;
    }
    
    /// @notice Creates a rebalance payload with random parameters
    function _createRebalancePayload(
        address vault,
        uint256 seed,
        bool enableSwap,
        bool enablePositionChanges,
        bool enableNewPositions
    ) internal view returns (bytes memory) {
        RebalanceParams memory params;
        
        if (enablePositionChanges) {
            params = _generateComplexRebalanceParams(vault, seed, enableSwap, enableNewPositions);
        } else {
            params = _generateSimpleRebalanceParams(vault, seed);
        }
        
        return abi.encodeWithSelector(
            IPancakeSwapV3StandardModule.rebalance.selector,
            params
        );
    }
    
    /// @notice Generates simple rebalance parameters (no position modifications)
    function _generateSimpleRebalanceParams(
        address vault,
        uint256 seed
    ) internal pure returns (RebalanceParams memory) {
        uint256 seed1 = uint256(keccak256(abi.encodePacked(seed, "burn")));
        uint256 seed2 = uint256(keccak256(abi.encodePacked(seed, "mint")));
        
        return RebalanceParams({
            decreasePositions: new ModifyPosition[](0),
            increasePositions: new ModifyPosition[](0),
            swapPayload: SwapPayload({
                payload: "",
                router: address(0),
                amountIn: 0,
                expectedMinReturn: 0,
                zeroForOne: false
            }),
            mintParams: new INonfungiblePositionManagerPancake.MintParams[](0),
            minBurn0: seed1 % 1000,
            minBurn1: seed2 % 1000,
            minDeposit0: 0,
            minDeposit1: 0
        });
    }
    
    /// @notice Generates complex rebalance parameters with position modifications
    function _generateComplexRebalanceParams(
        address vault,
        uint256 seed,
        bool enableSwap,
        bool enableNewPositions
    ) internal view returns (RebalanceParams memory) {
        uint256 seed1 = uint256(keccak256(abi.encodePacked(seed, "complex1")));
        uint256 seed2 = uint256(keccak256(abi.encodePacked(seed, "complex2")));
        
        RebalanceParams memory params;
        
        // Generate random position modifications (decrease/increase)
        if (seed1 % 2 == 0) {
            params.decreasePositions = _generateRandomDecreasePositions(seed1);
        }
        
        if (seed2 % 2 == 0) {
            params.increasePositions = _generateRandomIncreasePositions(seed2);
        }
        
        // Generate swap if enabled
        if (enableSwap && (seed % 3 == 0)) {
            params.swapPayload = _generateRandomSwapPayload(seed);
        }
        
        // Generate new positions if enabled
        if (enableNewPositions && (seed % 4 == 0)) {
            params.mintParams = _generateRandomMintParams(vault, seed);
        }
        
        // Set min bounds
        params.minBurn0 = seed1 % 1000;
        params.minBurn1 = seed2 % 1000;
        params.minDeposit0 = seed % 500;
        params.minDeposit1 = (seed * 2) % 500;
        
        return params;
    }
    
    /// @notice Generates random decrease position operations
    function _generateRandomDecreasePositions(
        uint256 seed
    ) internal pure returns (ModifyPosition[] memory) {
        uint256 count = (seed % 2) + 1; // 1-2 positions
        ModifyPosition[] memory positions = new ModifyPosition[](count);
        
        for (uint256 i = 0; i < count; i++) {
            positions[i] = ModifyPosition({
                tokenId: (seed + i) % 10000, // Random token ID
                proportion: ((seed + i) % 100) + 1 // 1-100% proportion
            });
        }
        
        return positions;
    }
    
    /// @notice Generates random increase position operations
    function _generateRandomIncreasePositions(
        uint256 seed
    ) internal pure returns (ModifyPosition[] memory) {
        uint256 count = (seed % 2) + 1; // 1-2 positions
        ModifyPosition[] memory positions = new ModifyPosition[](count);
        
        for (uint256 i = 0; i < count; i++) {
            positions[i] = ModifyPosition({
                tokenId: (seed + i) % 10000, // Random token ID
                proportion: ((seed + i) % 100) + 1 // 1-100% proportion
            });
        }
        
        return positions;
    }
    
    /// @notice Generates random swap payload
    function _generateRandomSwapPayload(
        uint256 seed
    ) internal pure returns (SwapPayload memory) {
        return SwapPayload({
            payload: abi.encodePacked(seed), // Dummy payload
            router: address(uint160(seed % type(uint160).max)), // Random router
            amountIn: (seed % 1e18) + 1, // Random amount
            expectedMinReturn: seed % 1e15, // Random min return
            zeroForOne: seed % 2 == 0 // Random direction
        });
    }
    
    /// @notice Generates random mint parameters
    function _generateRandomMintParams(
        address vault,
        uint256 seed
    ) internal view returns (INonfungiblePositionManagerPancake.MintParams[] memory) {
        // For simplicity, return empty array - actual implementation would need
        // to fetch vault tokens and create valid mint parameters
        return new INonfungiblePositionManagerPancake.MintParams[](0);
    }
    
    /// @notice Generates a pseudo-random seed
    function _generateSeed(uint256 baseSeed) internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            baseSeed,
            block.timestamp,
            block.number,
            nonce++
        )));
    }
    
    /// @notice Logs rebalance operation for analysis
    function _logRebalance(address vault, uint256 payloadsCount, bool success) internal {
        rebalanceHistory.push(RebalanceLog({
            vault: vault,
            timestamp: block.timestamp,
            payloadsCount: payloadsCount,
            success: success
        }));
        
        vaultRebalanceCount[vault]++;
    }
    
    /// @notice Returns rebalance history
    function getRebalanceHistory() external view returns (RebalanceLog[] memory) {
        return rebalanceHistory;
    }
    
    /// @notice Returns rebalance count for a specific vault
    function getVaultRebalanceCount(address vault) external view returns (uint256) {
        return vaultRebalanceCount[vault];
    }
    
    /// @notice Returns total number of rebalances executed
    function getTotalRebalances() external view returns (uint256) {
        return rebalanceHistory.length;
    }
}