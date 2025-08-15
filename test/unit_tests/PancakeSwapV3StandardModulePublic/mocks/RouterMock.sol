// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RouterMock {
    uint256 public constant SLIPPAGE_FACTOR = 950; // 5% slippage
    
    // Mock swap function that simulates token swaps
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin
    ) external returns (uint256 amountOut) {
        // Transfer tokens from caller
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        
        // Calculate mock output amount (apply slippage)
        amountOut = (amountIn * SLIPPAGE_FACTOR) / 1000;
        
        require(amountOut >= amountOutMin, "Insufficient output amount");
        
        // Transfer output tokens to caller
        IERC20(tokenOut).transfer(msg.sender, amountOut);
    }
    
    // Mock function to set token balances for testing
    function setBalance(address token, uint256 amount) external {
        // In a real router, this wouldn't exist
        // For testing, we assume tokens are magically available
    }
}