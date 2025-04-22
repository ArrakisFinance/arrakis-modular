// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {SwapPayload} from "../structs/SPancakeSwapV4.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IPoolManager} from
    "@pancakeswap/v4-core/src/interfaces/IPoolManager.sol";
import {IVault} from "@pancakeswap/v4-core/src/interfaces/IVault.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@pancakeswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

interface IPancakeSwapV4StandardModule {
    // #region errors.

    error Currency0DtToken0(address currency0, address token0);
    error Currency1DtToken1(address currency1, address token1);
    error Currency1DtToken0(address currency1, address token0);
    error Currency0DtToken1(address currency0, address token1);
    error RangeShouldBeActive(int24 tickLower, int24 tickUpper);
    error SqrtPriceZero();
    error OverBurning();
    error MaxSlippageGtTenPercent();
    error NativeCoinCannotBeToken1();
    error NoRemoveOrAddLiquidityHooks();
    error OnlyMetaVaultOwner();
    error InsufficientFunds();
    error OverMaxDeviation();
    error AmountZero();
    error BurnToken0();
    error BurnToken1();
    error MintToken0();
    error MintToken1();
    error SamePool();
    error ExpectedMinReturnTooLow();
    error InvalidCurrencyDelta();
    error WrongRouter();
    error SlippageTooHigh();
    error InvalidMsgValue();
    error OnlyVault();
    error TicksMisordered(int24 tickLower, int24 tickUpper);
    error TickLowerOutOfBounds(int24 tickLower);
    error TickUpperOutOfBounds(int24 tickUpper);
    error OnlyManagerOrVaultOwner();
    error LengthsNotEqual();
    error SameRewardReceiver();

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
    // #endregion structs.

    // #region events.
    event LogApproval(
        address indexed spender, uint256 amount0, uint256 amount1
    );
    event LogRebalance(
        LiquidityRange[] liquidityRanges,
        uint256 amount0Minted,
        uint256 amount1Minted,
        uint256 amount0Burned,
        uint256 amount1Burned
    );
    event LogSetPool(PoolKey oldPoolKey, PoolKey poolKey);
    event LogSetRewardReceiver(address rewardReceiver);
    // #endregion events.

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

    // #region only meta vault owner functions.

    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external;

    // #endregion only meta vault owner functions.

    // #region merkl rewards.

    function setClaimRecipient(address token_) external;

    // #endregion merkl rewards.

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

    // #region view functions.

    /// @notice function used to get the uniswap v4 pool manager.
    /// @return poolManager return the pool manager.
    function poolManager() external view returns (ICLPoolManager);

    /// @notice function used to know if the poolKey's currencies pair are inversed.
    function isInversed() external view returns (bool);

    function vault() external view returns (IVault);

    /// @notice function used to get the pool's key of the module.
    function poolKey()
        external
        view
        returns (
            Currency currency0,
            Currency currency1,
            IHooks hooks,
            IPoolManager poolManager,
            uint24 fee,
            bytes32 parameters
        );

    /// @notice function used to get the oracle that
    /// will be used to proctect rebalances.
    function oracle() external view returns (IOracleWrapper);


    /// @notice function used to get the max slippage that
    /// can occur during swap rebalance.
    function maxSlippage() external view returns (uint24);

    /// @notice function used to get the list of active ranges.
    /// @return ranges active ranges
    function getRanges() external view returns (Range[] memory ranges);

    // #endregion view functions.
}
