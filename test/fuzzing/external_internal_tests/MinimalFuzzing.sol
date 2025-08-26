// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

/// @title Minimal Fuzzing Test for Echidna
contract MinimalFuzzing {
    // State variables
    uint256 public totalDeposits;
    uint256 public totalWithdrawals;
    mapping(address => uint256) public userBalances;
    
    // ============ Fuzzing Functions ============
    
    /// @notice Test deposits
    function fuzz_deposit(uint256 amount) public {
        // Bound amount to prevent overflow
        if (amount == 0) return;
        if (amount > 1000000) amount = 1000000;
        
        // Update state
        totalDeposits += amount;
        userBalances[msg.sender] += amount;
        
        // Assertion
        assert(totalDeposits >= totalWithdrawals);
    }
    
    /// @notice Test withdrawals
    function fuzz_withdraw(uint256 amount) public {
        // Can't withdraw more than user balance
        if (userBalances[msg.sender] == 0) return;
        if (amount == 0) return;
        if (amount > userBalances[msg.sender]) amount = userBalances[msg.sender];
        
        // Update state
        totalWithdrawals += amount;
        userBalances[msg.sender] -= amount;
        
        // Assertion
        assert(totalWithdrawals <= totalDeposits);
    }
    
    /// @notice Balance check
    function fuzz_balance_check() public view {
        // Total withdrawals should never exceed deposits
        assert(totalWithdrawals <= totalDeposits);
    }
    
    // ============ Echidna Properties ============
    
    /// @notice Invariant: withdrawals never exceed deposits
    function echidna_withdrawals_bounded() public view returns (bool) {
        return totalWithdrawals <= totalDeposits;
    }
    
    /// @notice Invariant: user balance is reasonable
    function echidna_user_balance_reasonable() public view returns (bool) {
        return userBalances[msg.sender] <= totalDeposits;
    }
}