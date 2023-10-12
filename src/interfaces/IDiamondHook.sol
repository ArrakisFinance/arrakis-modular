// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IHooks} from "@uniswap/v4-core/contracts/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/contracts/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/contracts/types/Currency.sol";

interface IDiamondHook {
    // #region errors.

    error AlreadyInitialized();
    error NotPoolManagerToken();
    error InvalidTickSpacing();
    error InvalidMsgValue();
    error OnlyModifyViaHook();
    error PoolAlreadyOpened();
    error PoolNotOpen();
    error ArbTooSmall();
    error LiquidityZero();
    error InsufficientHedgeCommitted();
    error DepositZero();
    error WithdrawZero();
    error WithdrawExceedsAvailable();
    error OnlyCommitter();
    error PriceOutOfBounds();
    error TotalSupplyZero();
    error InvalidCurrencyDelta();
    error OverHundredPercent();
    error OnlyMetaVault(address caller, address metaVault);

    // #endregion errors.

    // #region structs.

    struct PoolManagerCalldata {
        uint256 amount; /// depositAmount | withdrawAmount | newSqrtPriceX96 (inferred from actionType)
        address msgSender;
        address receiver;
        uint8 actionType; /// 0 = deposit | 1 = withdraw | 2 = arbSwap
    }

    struct ArbSwapParams {
        uint160 sqrtPriceX96;
        uint160 newSqrtPriceX96;
        uint160 sqrtPriceX96Lower;
        uint160 sqrtPriceX96Upper;
        uint128 liquidity;
        uint24 betaFactor;
    }

    // #endregion structs.

    // #region view functions.

    /// @notice function to get the lower tick of the position.
    function lowerTick() external view returns (int24);

    /// @notice function to get the upper tick of the position.
    function upperTick() external view returns (int24);

    /// @notice function to get the tick spacing of the uni v4 hook.
    function tickSpacing() external view returns (int24);

    /// @notice function to get the initial rebate for block builder.
    /// % expressed as uint < 1e6
    function baseBeta() external view returns (uint24);

    /// @notice function to get the decay rate of the rebate.
    /// % expressed as uint < 1e6
    function decayRate() external view returns (uint24);

    /// @notice function to get the portion of tokens saved for
    /// LVR will be put again into the pool.
    function vaultRedepositRate() external view returns (uint24);

    /// @notice function to get the block number of the last pool open action.
    function lastBlockOpened() external view returns (uint256);

    /// @notice function to get the block number of the last pool reset.
    /// hedger tokens will go into the position.
    function lastBlockReset() external view returns (uint256);

    /// @notice function to get how much token0 needed to hedge the price shift
    /// from committed price.
    function hedgeRequired0() external view returns (uint256);

    /// @notice function to get how much token1 needed to hedge the price shift
    /// from committed price.
    function hedgeRequired1() external view returns (uint256);

    /// @notice function to get the amount of token0 committed by committer.
    /// that can be used to hedge against price shift from committed price.
    function hedgeCommitted0() external view returns (uint256);

    /// @notice function to get the amount of token1 committed by committer.
    /// that can be used to hedge against price shift from committed price.
    function hedgeCommitted1() external view returns (uint256);

    /// @notice function to get the committed price by committer.
    function committedSqrtPriceX96() external view returns (uint160);

    /// @notice function to get the poolKey of the uniswap v4 pool.
    function poolKey()
        external
        view
        returns (
            /// @notice The lower currency of the pool, sorted numerically
            Currency,
            /// @notice The higher currency of the pool, sorted numerically
            Currency,
            /// @notice The pool swap fee, capped at 1_000_000. The upper 4 bits determine if the hook sets any fees.
            uint24,
            /// @notice Ticks that involve positions must be a multiple of tick spacing
            int24,
            /// @notice The hooks of the pool
            IHooks
        );

    /// @notice function to get the address of the block producer wanting
    /// to open the pool.
    function committer() external view returns (address);

    /// @notice bool to know if the hook is initialized.
    function initialized() external view returns (bool);

    /// pure functions

    /// @notice get the minimum of two uint256.
    function min(uint256 a, uint256 b) external pure returns (uint256);

    /// @notice get the maximum of two uint256.
    function max(uint256 a, uint256 b) external pure returns (uint256);

    // #endergion view functions.

    // #region functions.

    function openPool(uint160 newSqrtPriceX96_) external payable;

    function depositHedgeCommitment(
        uint256 amount0_,
        uint256 amount1_
    ) external payable;

    function withdrawHedgeCommitment(
        uint256 amount0_,
        uint256 amount1_
    ) external;

    // #endregion functions.
}
