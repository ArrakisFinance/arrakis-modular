// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignALM} from "../../src/interfaces/ISovereignALM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SovereignALMMock is ISovereignALM {
    // #region Errors.

    error NotImplemented();

    // #endregion Errors.

    // #region public properties.

    uint256 public amount0;
    uint256 public amount1;
    uint256 public shares;

    address public token0;
    address public token1;

    address public module;

    // #endregion public properties.

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function getLiquidityQuote(
        ALMLiquidityQuoteInput memory,
        bytes calldata,
        bytes calldata
    ) external returns (ALMLiquidityQuote memory almLiquidityQuote) {
        revert NotImplemented();
    }

    function depositLiquidity(
        uint256 amount0_,
        uint256 amount1_,
        uint256 deadline_,
        uint256 minShares_,
        address recipient_,
        bytes calldata depositVerificationContext_
    ) external {
        amount0 += amount0_;
        amount1 += amount1_;
        shares += minShares_;

        IERC20(token0).transferFrom(module, address(this), amount0_);
        IERC20(token1).transferFrom(module, address(this), amount1_);
    }

    function withdrawLiquidity(
        uint256 shares_,
        uint256 amount0Min_,
        uint256 amount1Min_,
        uint256 deadline_,
        address recipient_,
        bytes calldata withdrawalVerificationContext_
    ) external returns (uint256 amt0, uint256 amt1) {
        amount0 -= amount0Min_;
        amount1 -= amount1Min_;
        shares -= shares_;
        IERC20(token0).transfer(recipient_, amount0Min_);
        IERC20(token1).transfer(recipient_, amount1Min_);

        amt0 = amount0Min_;
        amt1 = amount1Min_;
    }

    function getReserves()
        external
        view
        returns (uint128 reserves0, uint128 reserves1)
    {
        reserves0 = SafeCast.toUint128(IERC20(token0).balanceOf(address(this)));
        reserves1 = SafeCast.toUint128(IERC20(token1).balanceOf(address(this)));
    }

    function getReservesAtPrice(
        uint160 sqrtPriceX96_
    ) external view returns (uint128 reserves0, uint128 reserves1) {
        reserves0 = SafeCast.toUint128(IERC20(token0).balanceOf(address(this)));
        reserves1 = SafeCast.toUint128(IERC20(token1).balanceOf(address(this)));
    }

    function totalSupply() external view returns (uint256) {
        return shares;
    }

    function getSqrtOraclePriceX96()
        external
        view
        returns (uint160 sqrtOraclePriceX96)
    {
        return 0;
    }

    // #region mock functions.

    function setModule(address module_) public {
        module = module_;
    }

    // #endregion mock functions.
}
