// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISovereignALM} from "../interfaces/ISovereignALM.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

contract SovereignALM is ISovereignALM {
    using SafeERC20 for IERC20;

    // #region errors.

    error NotImplemented();
    error CannotDepositZero();
    error CannotWithdrawZero();
    error OnlyModule();

    // #endregion errors.

    // #region structs.

    struct UserPosition {
        uint256 amount0;
        uint256 amount1;
        uint256 mintShares;
    }

    // #endregion structs.

    // #region immutable properties.

    IERC20 public immutable token0;
    IERC20 public immutable token1;
    address public immutable module;

    // #endregion immutable properties.

    mapping(address => UserPosition) public userPosition;
    uint256 public totalSupply;

    // #region modifier.

    modifier onlyModule() {
        if (msg.sender != module) revert OnlyModule();
        _;
    }

    // #endregion modifier.

    constructor(
        address token0_,
        address token1_,
        address module_
    ) {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
        module = module_;
    }

    function depositLiquidity(
        uint256 amount0_,
        uint256 amount1_,
        uint256 deadline_,
        uint256 minShares_,
        address recipient_,
        bytes calldata depositVerificationContext_
    ) external onlyModule {
        if (amount0_ <= 0 && amount1_ <= 0) revert CannotDepositZero();

        userPosition[recipient_].amount0 += amount0_;
        userPosition[recipient_].amount1 += amount1_;
        userPosition[recipient_].mintShares += minShares_;

        totalSupply += minShares_;

        // #region get the tokens.

        if (amount0_ > 0)
            token0.safeTransferFrom(msg.sender, address(this), amount0_);

        if (amount1_ > 0)
            token1.safeTransferFrom(msg.sender, address(this), amount1_);

        // #endregion get the tokens.
    }

    function withdrawLiquidity(
        uint256 shares_,
        uint256 amount0Min_,
        uint256 amount1Min_,
        uint256 deadline_,
        address recipient_,
        bytes calldata withdrawalVerificationContext_
    ) external onlyModule returns (uint256 amount0, uint256 amount1) {
        if (amount0Min_ <= 0 && amount1Min_ <= 0) revert CannotWithdrawZero();

        userPosition[msg.sender].amount0 -= amount0Min_;
        userPosition[msg.sender].amount1 -= amount1Min_;
        userPosition[msg.sender].mintShares -= shares_;

        totalSupply -= shares_;

        // #region get the tokens.

        if (amount0Min_ > 0) token0.safeTransfer(recipient_, amount0Min_);

        if (amount1Min_ > 0) token1.safeTransfer(recipient_, amount1Min_);

        // #endregion get the tokens.

        return (amount0Min_, amount1Min_);
    }

    function getReserves()
        external
        view
        returns (uint128 reserves0, uint128 reserves1)
    {
        return (
            SafeCast.toUint128(token0.balanceOf(address(this))),
            SafeCast.toUint128(token1.balanceOf(address(this)))
        );
    }

    function getReservesAtPrice(
        uint160
    ) external view returns (uint128 reserves0, uint128 reserves1) {
        return (
            SafeCast.toUint128(token0.balanceOf(address(this))),
            SafeCast.toUint128(token1.balanceOf(address(this)))
        );
    }

    function getSqrtOraclePriceX96()
        external
        view
        returns (uint160 sqrtOraclePriceX96) {
            return 0;
        }
}
