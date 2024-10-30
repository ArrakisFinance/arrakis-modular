// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {UniV4StandardModule} from "./UniV4StandardModule.sol";
import {IUniV4StandardModuleRFQ} from
    "../interfaces/IUniV4StandardModuleRFQ.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";

import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

import {
    Currency
} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

abstract contract UniV4StandardModuleRFQ is
    UniV4StandardModule,
    IUniV4StandardModuleRFQ
{
    using SafeERC20 for IERC20Metadata;

    constructor(
        address poolManager_,
        address guardian_
    ) UniV4StandardModule(poolManager_, guardian_) {}

    // #region vault owner functions.

    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external nonReentrant {
        if (msg.sender == IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }

        token0.forceApprove(spender_, amount0_);
        token1.forceApprove(spender_, amount1_);

        emit LogApproval(spender_, amount0_, amount1_);
    }

    // #endregion vault owner functions.

    // #region override functions.

    function initializePosition(
        bytes calldata
    ) external virtual override onlyMetaVault {
        /// @dev left over will sit on the module.
    }

    function _withdrawCollectExtraFees(
        PoolKey memory poolKey_,
        uint256 amount0_,
        uint256 amount1_
    ) internal virtual override {
        if (amount0_ > 0) {
            poolManager.take(
                poolKey_.currency0, address(this), amount0_
            );
        }
        if (amount1_ > 0) {
            poolManager.take(
                poolKey_.currency1, address(this), amount1_
            );
        }
    }

    function _rebalanceSettle(
        PoolKey memory poolKey_,
        int256 amount0_,
        int256 amount1_
    ) internal virtual override {
        if (amount0_ > 0) {
            poolManager.take(
                poolKey_.currency0,
                address(this),
                SafeCast.toUint256(amount0_)
            );
        } else if (amount0_ < 0) {
            uint256 valueToSend;

            poolManager.sync(poolKey_.currency0);

            if (poolKey_.currency0.isAddressZero()) {
                valueToSend = SafeCast.toUint256(-amount0_);
            } else {
                IERC20Metadata(Currency.unwrap(poolKey_.currency0))
                    .safeTransfer(
                    address(poolManager),
                    SafeCast.toUint256(-amount0_)
                );
            }

            poolManager.settle{value: valueToSend}();
        }
        if (amount1_ > 0) {
            poolManager.take(
                poolKey_.currency0,
                address(this),
                SafeCast.toUint256(amount1_)
            );
        } else if (amount1_ < 0) {
            poolManager.sync(poolKey_.currency1);

            IERC20Metadata(Currency.unwrap(poolKey_.currency1))
                .safeTransfer(
                address(poolManager), SafeCast.toUint256(-amount1_)
            );

            poolManager.settle();
        }
    }

    function _initializePosition()
        internal
        virtual
        override
        returns (bytes memory result)
    {}

    function _getLeftOvers(
        PoolKey memory poolKey_
    )
        internal
        view
        virtual
        override
        returns (uint256 leftOver0, uint256 leftOver1)
    {
        leftOver0 = IERC20Metadata(
            Currency.unwrap(poolKey_.currency0)
        ).balanceOf(address(this));
        leftOver1 = IERC20Metadata(
            Currency.unwrap(poolKey_.currency1)
        ).balanceOf(address(this));
    }

    // #endregion override functions.
}
