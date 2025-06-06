// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IResolver} from "../../interfaces/IResolver.sol";
import {IPancakeSwapV4StandardModuleResolver} from
    "../../interfaces/IPancakeSwapV4StandardModuleResolver.sol";
import {IArrakisMetaVault} from
    "../../interfaces/IArrakisMetaVault.sol";
import {IPancakeSwapV4StandardModule} from
    "../../interfaces/IPancakeSwapV4StandardModule.sol";
import {IArrakisLPModule} from "../../interfaces/IArrakisLPModule.sol";
import {UnderlyingPayload} from "../../structs/SPancakeSwapV4.sol";
import {BASE} from "../../constants/CArrakis.sol";
import {PancakeSwapV4} from "../../libraries/PancakeSwapV4.sol";
import {Range as PoolRange} from "../../structs/SPancakeSwapV4.sol";
import {PancakeUnderlyingV4} from "../../libraries/PancakeUnderlyingV4.sol";

import {ICLPoolManager} from
    "@pancakeswap/v4-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IVault} from "@pancakeswap/v4-core/src/interfaces/IVault.sol";
import {FullMath} from
    "@pancakeswap/v4-core/src/pool-cl/libraries/FullMath.sol";
import {Currency} from "@pancakeswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PancakeSwapV4StandardModuleResolver is
    IResolver,
    IPancakeSwapV4StandardModuleResolver
{
    // #region immutable varaibles.

    address public immutable poolManager;

    // #endregion immutable variables.

    constructor(
        address poolManager_
    ) {
        if (poolManager_ == address(0)) {
            revert AddressZero();
        }

        poolManager = poolManager_;
    }

    /// @notice getMintAmounts used to get the shares we can mint from some max amounts.
    /// @param vault_ meta vault address.
    /// @param maxAmount0_ maximum amount of token0 user want to contribute.
    /// @param maxAmount1_ maximum amount of token1 user want to contribute.
    /// @return shareToMint maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.
    /// @return amount0ToDeposit amount of token0 user should deposit into the vault for minting 'shareToMint'.
    /// @return amount1ToDeposit amount of token1 user should deposit into the vault for minting 'shareToMint'.
    function getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    )
        external
        view
        returns (
            uint256 shareToMint,
            uint256 amount0ToDeposit,
            uint256 amount1ToDeposit
        )
    {
        uint256 totalSupply;
        address module;
        bool isInversed;

        PoolKey memory poolKey;
        UnderlyingPayload memory underlyingPayload;

        {
            PoolRange[] memory poolRanges;

            {
                totalSupply = IERC20(vault_).totalSupply();
                module = address(IArrakisMetaVault(vault_).module());

                isInversed =
                    IPancakeSwapV4StandardModule(module).isInversed();

                IPancakeSwapV4StandardModule.Range[] memory _ranges =
                    IPancakeSwapV4StandardModule(module).getRanges();

                uint256 buffer = 2 * _ranges.length;

                if (buffer >= maxAmount0_ || buffer >= maxAmount1_) {
                    revert MaxAmountsTooLow();
                }

                (maxAmount0_, maxAmount1_) = isInversed
                    ? (maxAmount1_, maxAmount0_)
                    : (maxAmount0_, maxAmount1_);

                maxAmount0_ =
                    maxAmount0_ > buffer ? maxAmount0_ - buffer : 0;
                maxAmount1_ =
                    maxAmount1_ > buffer ? maxAmount1_ - buffer : 0;

                poolRanges = new PoolRange[](_ranges.length);

                (
                    poolKey.currency0,
                    poolKey.currency1,
                    poolKey.hooks,
                    poolKey.poolManager,
                    poolKey.fee,
                    poolKey.parameters
                ) = IPancakeSwapV4StandardModule(module).poolKey();

                for (uint256 i; i < _ranges.length; i++) {
                    IPancakeSwapV4StandardModule.Range memory range =
                        _ranges[i];
                    poolRanges[i] = PoolRange({
                        lowerTick: range.tickLower,
                        upperTick: range.tickUpper,
                        poolKey: poolKey
                    });
                }
            }
            {
                uint256 leftOver0 = poolKey.currency0.isNative()
                    ? module.balance
                    : IERC20(Currency.unwrap(poolKey.currency0)).balanceOf(
                        module
                    );
                uint256 leftOver1 = IERC20(
                    Currency.unwrap(poolKey.currency1)
                ).balanceOf(module);

                underlyingPayload = UnderlyingPayload({
                    ranges: poolRanges,
                    poolManager: ICLPoolManager(poolManager),
                    self: module,
                    leftOver0: leftOver0,
                    leftOver1: leftOver1
                });
            }
        }

        if (totalSupply > 0) {
            (uint256 current0, uint256 current1) = PancakeUnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, BASE);

            shareToMint = computeMintAmounts(
                current0,
                current1,
                totalSupply,
                maxAmount0_,
                maxAmount1_
            );
            uint256 proportion = FullMath.mulDivRoundingUp(
                shareToMint, BASE, totalSupply
            );

            (amount0ToDeposit, amount1ToDeposit) = PancakeUnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, proportion);
        } else {
            (uint256 init0, uint256 init1) =
                IArrakisLPModule(module).getInits();

            (init0, init1) =
                isInversed ? (init1, init0) : (init0, init1);

            shareToMint = computeMintAmounts(
                init0, init1, BASE, maxAmount0_, maxAmount1_
            );

            // compute amounts owed to contract
            amount0ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init0, BASE);
            amount1ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init1, BASE);
        }

        (amount0ToDeposit, amount1ToDeposit) = isInversed
            ? (amount1ToDeposit, amount0ToDeposit)
            : (amount0ToDeposit, amount1ToDeposit);
    }

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) public pure returns (uint256 mintAmount) {
        // compute proportional amount of tokens to mint
        if (current0_ == 0 && current1_ > 0) {
            mintAmount =
                FullMath.mulDiv(amount1Max_, totalSupply_, current1_);
        } else if (current1_ == 0 && current0_ > 0) {
            mintAmount =
                FullMath.mulDiv(amount0Max_, totalSupply_, current0_);
        } else if (current0_ > 0 && current1_ > 0) {
            uint256 amount0Mint =
                FullMath.mulDiv(amount0Max_, totalSupply_, current0_);
            uint256 amount1Mint =
                FullMath.mulDiv(amount1Max_, totalSupply_, current1_);

            if (amount0Mint == 0 || amount1Mint == 0) {
                revert MintZero();
            }

            mintAmount =
                amount0Mint < amount1Mint ? amount0Mint : amount1Mint;
        }
    }
}
