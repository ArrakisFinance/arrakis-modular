// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {PancakeSwapV3StandardModule} from
    "../abstracts/PancakeSwapV3StandardModule.sol";
import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PancakeSwapV3StandardModulePrivate is
    PancakeSwapV3StandardModule,
    IArrakisLPModulePrivate
{
    using SafeERC20 for IERC20Metadata;
    // #region public constants.

    /// @dev id = keccak256(abi.encode("PancakeSwapV3StandardModulePrivate"))
    bytes32 public constant id =
        0x44e4a7ca74b28d7356e41d25bca1843604b4c48e4ae397efa6c5a36d3fa7db7a;

    // #endregion public constants.

    constructor(
        address guardian_,
        address nftPositionManager_,
        address factory_,
        address cake_,
        address masterChefV3_
    )
        PancakeSwapV3StandardModule(
            guardian_,
            nftPositionManager_,
            factory_,
            cake_,
            masterChefV3_
        )
    {}

    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyMetaVault whenNotPaused nonReentrant {
        // #region checks.

        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();
        if (msg.value > 0) revert NativeCoinNotAllowed();

        // #endregion checks.

        // #endregion get liquidity for each positions and mint.

        if (amount0_ > 0) {
            token0.safeTransferFrom(
                depositor_, address(this), amount0_
            );
        }

        if (amount1_ > 0) {
            token1.safeTransferFrom(
                depositor_, address(this), amount1_
            );
        }

        // #endregion get how much left over we have on poolManager and mint.
    }
}
