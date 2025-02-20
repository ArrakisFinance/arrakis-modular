// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IResolver} from "../../interfaces/IResolver.sol";
import {IArrakisMetaVault} from "../../interfaces/IArrakisMetaVault.sol";
import {BASE} from "../../constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ValantisResolver is
    IResolver
{
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
        (uint256 amount0, uint256 amount1) =
            IArrakisMetaVault(vault_).totalUnderlying();

        uint256 supply = IERC20(vault_).totalSupply();

        if (supply == 0) {
            (amount0, amount1) = IArrakisMetaVault(vault_).getInits();
            supply = BASE;
        }

        uint256 proportion0 = amount0 == 0
            ? type(uint256).max
            : FullMath.mulDiv(maxAmount0_, BASE, amount0);
        uint256 proportion1 = amount1 == 0
            ? type(uint256).max
            : FullMath.mulDiv(maxAmount1_, BASE, amount1);

        uint256 proportion =
            proportion0 < proportion1 ? proportion0 : proportion1;

        shareToMint = FullMath.mulDiv(proportion, supply, BASE);

        proportion = FullMath.mulDivRoundingUp(
            shareToMint, BASE, supply
        );

        amount0ToDeposit =
            FullMath.mulDivRoundingUp(amount0, proportion, BASE);
        amount1ToDeposit =
            FullMath.mulDivRoundingUp(amount1, proportion, BASE);
    }
}