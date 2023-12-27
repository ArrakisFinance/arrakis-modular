// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

interface ISovereignALM {

    // #region valantis structs.

    struct ALMLiquidityQuoteInput {
        bool isZeroToOne;
        uint256 amountInMinusFee;
        uint256 fee;
        address sender;
        address recipient;
        address tokenOutSwap;
    }

    struct ALMLiquidityQuote {
        bool quoteFromPoolReserves;
        bool isCallbackOnSwap;
        uint256 amountOut;
        uint256 amountInFilled;
    }

    // #endregion valantis structs.

    function getLiquidityQuote(
        ALMLiquidityQuoteInput memory almLiquidityQuoteInput_,
        bytes calldata externalContext_,
        bytes calldata
    ) external returns (ALMLiquidityQuote memory almLiquidityQuote);

    function depositLiquidity(
        uint256 amount0_,
        uint256 amount1_,
        uint256 deadline_,
        uint256 minShares_,
        address recipient_,
        bytes calldata depositVerificationContext_
    ) external;

    function withdrawLiquidity(
        uint256 shares_,
        uint256 amount0Min_,
        uint256 amount1Min_,
        uint256 deadline_,
        address recipient_,
        bytes calldata withdrawalVerificationContext_
    ) external returns (uint256 amount0, uint256 amount1);

    function getReserves()
        external
        view
        returns (uint128 reserves0, uint128 reserves1);

    function getReservesAtPrice(
        uint160 sqrtPriceX96_
    ) external view returns (uint128 reserves0, uint128 reserves1);

    function totalSupply() external view returns (uint256);
}
