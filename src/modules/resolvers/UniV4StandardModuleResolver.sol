// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IResolver} from "../../interfaces/IResolver.sol";
import {IUniV4StandardModuleResolver} from
    "../../interfaces/IUniV4StandardModuleResolver.sol";
import {IArrakisMetaVault} from
    "../../interfaces/IArrakisMetaVault.sol";
import {IUniV4StandardModule} from
    "../../interfaces/IUniV4StandardModule.sol";
import {IArrakisLPModule} from "../../interfaces/IArrakisLPModule.sol";
import {UnderlyingPayload} from "../../structs/SUniswapV4.sol";
import {BASE} from "../../constants/CArrakis.sol";
import {UnderlyingV4} from "../../libraries/UnderlyingV4.sol";
import {Range as PoolRange} from "../../structs/SUniswapV4.sol";

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract UniV4StandardModuleResolver is
    IResolver,
    IUniV4StandardModuleResolver
{
    // #region immutable variables.

    address public immutable poolManager;

    // #endregion immutable vairable.

    constructor(address poolManager_) {
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
        PoolRange[] memory poolRanges;
        uint256 totalSupply;
        address module;

        {
            totalSupply = IERC20(vault_).totalSupply();
            module = address(IArrakisMetaVault(vault_).module());

            IUniV4StandardModule.Range[] memory _ranges =
                IUniV4StandardModule(module).getRanges();
            
            uint256 numberOfRanges = _ranges.length;

            if (
                _ranges.length >= maxAmount0_
                    || _ranges.length >= maxAmount1_
            ) {
                revert MaxAmountsTooLow();
            }

            maxAmount0_ = maxAmount0_ - numberOfRanges;
            maxAmount1_ = maxAmount1_ - numberOfRanges;

            

            poolRanges = new PoolRange[](_ranges.length);

            PoolKey memory poolKey;
            (
                poolKey.currency0,
                poolKey.currency1,
                poolKey.fee,
                poolKey.tickSpacing,
                poolKey.hooks
            ) = IUniV4StandardModule(module).poolKey();

            for (uint256 i; i < _ranges.length; i++) {
                IUniV4StandardModule.Range memory range = _ranges[i];
                poolRanges[i] = PoolRange({
                    lowerTick: range.tickLower,
                    upperTick: range.tickUpper,
                    poolKey: poolKey
                });
            }
        }

        UnderlyingPayload memory underlyingPayload;

        {address token0 = address(IArrakisLPModule(module).token0());
        address token1 = address(IArrakisLPModule(module).token1());
        underlyingPayload = UnderlyingPayload({
            ranges: poolRanges,
            poolManager: IPoolManager(poolManager),
            token0: token0,
            token1: token1,
            self: module
        });}

        if (totalSupply > 0) {
            (uint256 current0, uint256 current1) = UnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, BASE);

            shareToMint = computeMintAmounts(
                current0,
                current1,
                totalSupply,
                maxAmount0_,
                maxAmount1_
            );
            uint256 proportion =
                FullMath.mulDiv(shareToMint, 1e18, totalSupply);
            (amount0ToDeposit, amount1ToDeposit) = UnderlyingV4
                .totalUnderlyingForMint(underlyingPayload, proportion);
        } else {
            (uint256 init0, uint256 init1) = IArrakisLPModule(module).getInits();
            shareToMint = computeMintAmounts(
                init0, init1, 1 ether, maxAmount0_, maxAmount1_
            );

            // compute amounts owed to contract
            amount0ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init0, 1 ether);
            amount1ToDeposit =
                FullMath.mulDivRoundingUp(shareToMint, init1, 1 ether);
        }
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
        } else {
            revert NotSupported();
        }
    }
}
