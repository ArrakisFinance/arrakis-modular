// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {SwapPayload} from "../structs/SUniswapV4.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

interface IUniV4StandardModule {
    // #region errors.

    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error Currency1DtToken0(address currency1, address token0);
    error Currency0DtToken1(address currency0, address token1);
    error SqrtPriceZero();
    error OnlyPoolManager();
    error InvalidCurrencyDelta();
    error RangeShouldBeActive(int24 tickLower, int24 tickUpper);
    error OverBurning();
    error TicksMisordered(int24 tickLower, int24 tickUpper);
    error TickLowerOutOfBounds(int24 tickLower);
    error TickUpperOutOfBounds(int24 tickUpper);
    error SamePool();
    error NoRemoveOrAddLiquidityHooks();
    error OverMaxDeviation();
    error NativeCoinCannotBeToken1();
    error MaxSlippageGtTenPercent();
    error ExpectedMinReturnTooLow();
    error WrongRouter();
    error SlippageTooHigh();
    error OnlyMetaVaultOwner();
    error InvalidMsgValue();
    error InsufficientFunds();
    error AmountZero();
    error BurnToken0();
    error BurnToken1();
    error MintToken0();
    error MintToken1();
    error LengthsNotEqual();
    error CollectorIsOperator();

    // #endregion errors.

    // #region structs.

    struct Range {
        int24 tickLower;
        int24 tickUpper;
    }

    struct LiquidityRange {
        Range range;
        int128 liquidity;
    }

    event LogApproval(
        address indexed spender, address[] tokens, uint256[] amounts
    );

    // #endregion structs.

    // #region events.

    event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
    event LogRebalance(
        LiquidityRange[] liquidityRanges,
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );

    // #endregion events.

    // #region only meta vault owner functions.

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the uniswap v4 standard module.
    /// @dev this function will deposit fund as left over on poolManager.
    /// @param init0_ initial amount of token0 to provide to uniswap standard module.
    /// @param init1_ initial amount of token1 to provide to valantis module.
    /// @param isInversed_ boolean to check if the poolKey's currencies pair are inversed,
    /// compared to the module's tokens pair.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param oracle_ address of the oracle used by the uniswap v4 standard module.
    /// @param maxSlippage_ allowed to manager for rebalancing the inventory using
    /// swap.
    /// @param metaVault_ address of the meta vault
    function initialize(
        uint256 init0_,
        uint256 init1_,
        bool isInversed_,
        PoolKey calldata poolKey_,
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address metaVault_
    ) external;

    // #endregion only meta vault owner functions.

    // #region only meta vault owner functions.

    /// @notice function used to approve a spender to use the left over of the module.
    /// @param spender_ address that will be allowed to use left over.
    /// @param tokens_ tokens allowed to be used by spender.
    /// @param amounts_ amounts allowed to be used by spender.
    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external;

    // #endregion only meta vault owner functions.

    // #region only manager functions.

    /// @notice function used to set the pool for the module.
    /// @param poolKey_ pool key of the uniswap v4 pool that will be used by the module.
    /// @param liquidityRanges_ list of liquidity ranges to be used by the module on the new pool.
    /// @param swapPayload_ swap payload to be used during rebalance.
    /// @param minBurn0_ minimum amount of token0 to burn.
    /// @param minBurn1_ minimum amount of token1 to burn.
    /// @param minDeposit0_ minimum amount of token0 to deposit.
    /// @param minDeposit1_ minimum amount of token1 to deposit.
    function setPool(
        PoolKey calldata poolKey_,
        LiquidityRange[] calldata liquidityRanges_,
        SwapPayload calldata swapPayload_,
        uint256 minBurn0_,
        uint256 minBurn1_,
        uint256 minDeposit0_,
        uint256 minDeposit1_
    ) external;

    /// @notice function used to rebalance the inventory of the module.
    /// @param liquidityRanges_ list of liquidity ranges to be used by the module.
    /// @param swapPayload_ swap payload to be used during rebalance.
    /// @param minBurn0_ minimum amount of token0 to burn.
    /// @param minBurn1_ minimum amount of token1 to burn.
    /// @param minDeposit0_ minimum amount of token0 to deposit.
    /// @param minDeposit1_ minimum amount of token1 to deposit.
    /// @return amount0Minted amount of token0 minted.
    /// @return amount1Minted amount of token1 minted.
    /// @return amount0Burned amount of token0 burned.
    /// @return amount1Burned amount of token1 burned.
    function rebalance(
        LiquidityRange[] calldata liquidityRanges_,
        SwapPayload memory swapPayload_,
        uint256 minBurn0_,
        uint256 minBurn1_,
        uint256 minDeposit0_,
        uint256 minDeposit1_
    )
        external
        returns (
            uint256 amount0Minted,
            uint256 amount1Minted,
            uint256 amount0Burned,
            uint256 amount1Burned
        );

    /// @notice function used to withdraw eth from the module.
    /// @dev these fund will be used to swap eth to the other token
    /// of the currencyPair to rebalance the inventory inside a single tx.
    function withdrawEth(
        uint256 amount_
    ) external;

    // #endregion only manager functions.

    /// @dev function to assign operator role to collector.
    function toggleOperator() external;

    // #region view functions.

    /// @notice function used to get eth withdrawers allowances.
    function ethWithdrawers(
        address
    ) external view returns (uint256);

    /// @notice function used to get the list of active ranges.
    /// @return ranges active ranges
    function getRanges()
        external
        view
        returns (Range[] memory ranges);

    /// @notice function used to get the pool's key of the module.
    /// @return currency0 currency0 of the pool.
    /// @return currency1 currency1 of the pool.
    /// @return fee fee of the pool.
    /// @return tickSpacing tick spacing of the pool.
    /// @return hooks hooks of the pool.
    function poolKey()
        external
        view
        returns (
            Currency currency0,
            Currency currency1,
            uint24 fee,
            int24 tickSpacing,
            IHooks hooks
        );

    /// @notice function used to get the uniswap v4 pool manager.
    /// @return poolManager return the pool manager.
    function poolManager() external view returns (IPoolManager);

    /// @notice function used to know if the poolKey's currencies pair are inversed.
    function isInversed() external view returns (bool);

    /// @notice function used to get the max slippage that
    /// can occur during swap rebalance.
    function maxSlippage() external view returns (uint24);

    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);

    // #endregion view functions.
}
