// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IArrakisMetaVaultPrivate} from "../../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVaultPublic} from "../../../src/interfaces/IArrakisMetaVaultPublic.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract UserActor {
    using SafeERC20 for IERC20;
    
    // Track user interactions for analysis
    struct InteractionLog {
        address vault;
        bool isPrivate;
        string action; // "deposit", "withdraw", "mint", "burn"
        uint256 amount0;
        uint256 amount1;
        uint256 shares; // For public vaults
        uint256 timestamp;
        bool success;
    }
    
    InteractionLog[] public interactionHistory;
    mapping(address => uint256) public vaultInteractionCount;
    
    // User balance tracking
    mapping(address => mapping(address => uint256)) public userTokenBalances; // user => token => balance
    mapping(address => mapping(address => uint256)) public userShares; // user => vault => shares
    
    uint256 public nonce;
    
    event UserInteraction(
        address indexed user,
        address indexed vault,
        string action,
        uint256 amount0,
        uint256 amount1,
        uint256 shares,
        bool success
    );
    
    /// @notice Executes random deposit operation on a private vault
    /// @param vault Private vault address
    /// @param user User address performing the action
    /// @param seedValue Random seed for amount generation
    /// @param maxAmount0 Maximum amount of token0 to use
    /// @param maxAmount1 Maximum amount of token1 to use
    function randomPrivateDeposit(
        address vault,
        address user,
        uint256 seedValue,
        uint256 maxAmount0,
        uint256 maxAmount1
    ) external {
        require(vault != address(0), "Vault address zero");
        require(user != address(0), "User address zero");
        
        uint256 seed1 = _generateSeed(seedValue, "deposit0");
        uint256 seed2 = _generateSeed(seedValue, "deposit1");
        
        uint256 amount0 = maxAmount0 > 0 ? (seed1 % maxAmount0) : 0;
        uint256 amount1 = maxAmount1 > 0 ? (seed2 % maxAmount1) : 0;
        
        // Ensure at least one amount is non-zero
        if (amount0 == 0 && amount1 == 0) {
            amount0 = maxAmount0 > 0 ? 1 : 0;
            amount1 = maxAmount1 > 0 ? 1 : 0;
        }
        
        try IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1) {
            _logInteraction(user, vault, true, "deposit", amount0, amount1, 0, true);
            emit UserInteraction(user, vault, "deposit", amount0, amount1, 0, true);
        } catch Error(string memory reason) {
            _logInteraction(user, vault, true, "deposit", amount0, amount1, 0, false);
            emit UserInteraction(user, vault, "deposit", amount0, amount1, 0, false);
        } catch {
            _logInteraction(user, vault, true, "deposit", amount0, amount1, 0, false);
            emit UserInteraction(user, vault, "deposit", amount0, amount1, 0, false);
        }
    }
    
    /// @notice Executes random withdraw operation on a private vault
    /// @param vault Private vault address
    /// @param user User address performing the action
    /// @param receiver Address to receive withdrawn tokens
    /// @param seedValue Random seed for proportion generation
    function randomPrivateWithdraw(
        address vault,
        address user,
        address receiver,
        uint256 seedValue
    ) external {
        require(vault != address(0), "Vault address zero");
        require(user != address(0), "User address zero");
        require(receiver != address(0), "Receiver address zero");
        
        uint256 seed = _generateSeed(seedValue, "withdraw");
        
        // Generate random proportion (1-100%)
        uint256 proportion = (seed % 100) + 1;
        
        try IArrakisMetaVaultPrivate(vault).withdraw(proportion, receiver) 
        returns (uint256 amount0, uint256 amount1) {
            _logInteraction(user, vault, true, "withdraw", amount0, amount1, 0, true);
            emit UserInteraction(user, vault, "withdraw", amount0, amount1, 0, true);
        } catch Error(string memory reason) {
            _logInteraction(user, vault, true, "withdraw", 0, 0, 0, false);
            emit UserInteraction(user, vault, "withdraw", 0, 0, 0, false);
        } catch {
            _logInteraction(user, vault, true, "withdraw", 0, 0, 0, false);
            emit UserInteraction(user, vault, "withdraw", 0, 0, 0, false);
        }
    }
    
    /// @notice Executes random mint operation on a public vault
    /// @param vault Public vault address
    /// @param user User address performing the action
    /// @param receiver Address to receive shares
    /// @param seedValue Random seed for shares generation
    /// @param maxShares Maximum shares to mint
    function randomPublicMint(
        address vault,
        address user,
        address receiver,
        uint256 seedValue,
        uint256 maxShares
    ) external {
        require(vault != address(0), "Vault address zero");
        require(user != address(0), "User address zero");
        require(receiver != address(0), "Receiver address zero");
        
        uint256 seed = _generateSeed(seedValue, "mint");
        uint256 shares = maxShares > 0 ? (seed % maxShares) + 1 : 1;
        
        try IArrakisMetaVaultPublic(vault).mint(shares, receiver) 
        returns (uint256 amount0, uint256 amount1) {
            userShares[user][vault] += shares;
            _logInteraction(user, vault, false, "mint", amount0, amount1, shares, true);
            emit UserInteraction(user, vault, "mint", amount0, amount1, shares, true);
        } catch Error(string memory reason) {
            _logInteraction(user, vault, false, "mint", 0, 0, shares, false);
            emit UserInteraction(user, vault, "mint", 0, 0, shares, false);
        } catch {
            _logInteraction(user, vault, false, "mint", 0, 0, shares, false);
            emit UserInteraction(user, vault, "mint", 0, 0, shares, false);
        }
    }
    
    /// @notice Executes random burn operation on a public vault
    /// @param vault Public vault address
    /// @param user User address performing the action
    /// @param receiver Address to receive tokens
    /// @param seedValue Random seed for shares generation
    function randomPublicBurn(
        address vault,
        address user,
        address receiver,
        uint256 seedValue
    ) external {
        require(vault != address(0), "Vault address zero");
        require(user != address(0), "User address zero");
        require(receiver != address(0), "Receiver address zero");
        
        uint256 userShareBalance = userShares[user][vault];
        if (userShareBalance == 0) {
            // User has no shares to burn
            _logInteraction(user, vault, false, "burn", 0, 0, 0, false);
            emit UserInteraction(user, vault, "burn", 0, 0, 0, false);
            return;
        }
        
        uint256 seed = _generateSeed(seedValue, "burn");
        uint256 shares = (seed % userShareBalance) + 1; // Burn 1 to all shares
        
        try IArrakisMetaVaultPublic(vault).burn(shares, receiver) 
        returns (uint256 amount0, uint256 amount1) {
            userShares[user][vault] -= shares;
            _logInteraction(user, vault, false, "burn", amount0, amount1, shares, true);
            emit UserInteraction(user, vault, "burn", amount0, amount1, shares, true);
        } catch Error(string memory reason) {
            _logInteraction(user, vault, false, "burn", 0, 0, shares, false);
            emit UserInteraction(user, vault, "burn", 0, 0, shares, false);
        } catch {
            _logInteraction(user, vault, false, "burn", 0, 0, shares, false);
            emit UserInteraction(user, vault, "burn", 0, 0, shares, false);
        }
    }
    
    /// @notice Executes a sequence of random user interactions
    /// @param vault Vault address
    /// @param user User address
    /// @param isPrivate Whether the vault is private or public
    /// @param seedValue Base seed for randomization
    /// @param interactions Number of interactions to perform
    /// @param maxAmount0 Maximum token0 amount for operations
    /// @param maxAmount1 Maximum token1 amount for operations
    /// @param maxShares Maximum shares for public vault operations
    function executeRandomInteractionSequence(
        address vault,
        address user,
        bool isPrivate,
        uint256 seedValue,
        uint256 interactions,
        uint256 maxAmount0,
        uint256 maxAmount1,
        uint256 maxShares
    ) external {
        for (uint256 i = 0; i < interactions; i++) {
            uint256 actionSeed = _generateSeed(seedValue + i, "sequence");
            uint256 actionType = actionSeed % 4;
            
            if (isPrivate) {
                if (actionType < 2) {
                    // Deposit
                    this.randomPrivateDeposit(vault, user, actionSeed, maxAmount0, maxAmount1);
                } else {
                    // Withdraw
                    this.randomPrivateWithdraw(vault, user, user, actionSeed);
                }
            } else {
                if (actionType < 2) {
                    // Mint
                    this.randomPublicMint(vault, user, user, actionSeed, maxShares);
                } else {
                    // Burn
                    this.randomPublicBurn(vault, user, user, actionSeed);
                }
            }
        }
    }
    
    /// @notice Simulates token approvals for vault interactions
    /// @param token Token to approve
    /// @param vault Vault to approve for
    /// @param amount Amount to approve
    function approveToken(address token, address vault, uint256 amount) external {
        IERC20(token).safeApprove(vault, amount);
    }
    
    /// @notice Funds user with tokens for testing
    /// @param user User to fund
    /// @param token Token to transfer
    /// @param amount Amount to transfer
    function fundUser(address user, address token, uint256 amount) external {
        // In a real scenario, this would transfer from a treasury or mint tokens
        // For fuzzing, we assume tokens are available
        userTokenBalances[user][token] += amount;
    }
    
    /// @notice Generates pseudo-random seed
    function _generateSeed(uint256 baseSeed, string memory salt) internal returns (uint256) {
        return uint256(keccak256(abi.encodePacked(
            baseSeed,
            salt,
            block.timestamp,
            block.number,
            nonce++
        )));
    }
    
    /// @notice Logs user interaction for analysis
    function _logInteraction(
        address user,
        address vault,
        bool isPrivate,
        string memory action,
        uint256 amount0,
        uint256 amount1,
        uint256 shares,
        bool success
    ) internal {
        interactionHistory.push(InteractionLog({
            vault: vault,
            isPrivate: isPrivate,
            action: action,
            amount0: amount0,
            amount1: amount1,
            shares: shares,
            timestamp: block.timestamp,
            success: success
        }));
        
        vaultInteractionCount[vault]++;
    }
    
    /// @notice Returns interaction history
    function getInteractionHistory() external view returns (InteractionLog[] memory) {
        return interactionHistory;
    }
    
    /// @notice Returns interaction count for a specific vault
    function getVaultInteractionCount(address vault) external view returns (uint256) {
        return vaultInteractionCount[vault];
    }
    
    /// @notice Returns total number of interactions
    function getTotalInteractions() external view returns (uint256) {
        return interactionHistory.length;
    }
    
    /// @notice Returns user's share balance in a vault
    function getUserShares(address user, address vault) external view returns (uint256) {
        return userShares[user][vault];
    }
    
    /// @notice Returns user's token balance
    function getUserTokenBalance(address user, address token) external view returns (uint256) {
        return userTokenBalances[user][token];
    }
    
    /// @notice Returns success rate for a specific vault
    function getVaultSuccessRate(address vault) external view returns (uint256, uint256) {
        uint256 totalInteractions = 0;
        uint256 successfulInteractions = 0;
        
        for (uint256 i = 0; i < interactionHistory.length; i++) {
            if (interactionHistory[i].vault == vault) {
                totalInteractions++;
                if (interactionHistory[i].success) {
                    successfulInteractions++;
                }
            }
        }
        
        return (successfulInteractions, totalInteractions);
    }
}