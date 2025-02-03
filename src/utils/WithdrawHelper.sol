// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IWithdrawHelper} from "../interfaces/IWithdrawHelper.sol";
import {ISafe, Operation} from "../interfaces/ISafe.sol";
import {IArrakisMetaVaultPrivate} from
    "../interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {BASE} from "../constants/CArrakis.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WithdrawHelper is IWithdrawHelper {
    function withdraw(
        address safe_,
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
        address receiver_
    ) external override {

        // #region checks.

        if(msg.sender != safe_) {
            revert Unauthorized();
        }

        // #endregion checks.

        uint256 proportion;
        bytes memory payload;

        // #region get underlying.

        {
            (uint256 total0, uint256 total1) =
                IArrakisMetaVault(vault_).totalUnderlying();

            if (amount0_ > total0 || amount1_ > total1) {
                revert InsufficientUnderlying();
            }

            uint256 proportion0 =
                FullMath.mulDiv(amount0_, BASE, total0);
            uint256 proportion1 =
                FullMath.mulDiv(amount1_, BASE, total1);

            proportion =
                proportion0 > proportion1 ? proportion0 : proportion1;
        }

        // #endregion get underlying.

        // #region balance of safe.

        address token0 = IArrakisMetaVault(vault_).token0();
        address token1 = IArrakisMetaVault(vault_).token1();

        uint256 balance0 = IERC20(token0).balanceOf(safe_);
        uint256 balance1 = IERC20(token1).balanceOf(safe_);

        // #endregion balance of safe.

        // #region withdraw liquidity.

        {
            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.withdraw.selector,
                proportion,
                safe_
            );

            ISafe(safe_).execTransactionFromModule(
                vault_, 0, payload, Operation.Call
            );
        }

        // #endregion withdraw liquidity.

        balance0 = IERC20(token0).balanceOf(safe_) - balance0;
        balance1 = IERC20(token1).balanceOf(safe_) - balance1;

        // #region transfer amount0 and amount1 to receiver.

        if (amount0_ > 0) {
            uint256 amountToTransfer =
                amount0_ > balance0 ? balance0 : amount0_;
            balance0 -= amountToTransfer;
            payload = abi.encodeWithSelector(
                IERC20.transfer.selector, receiver_, amountToTransfer
            );

            ISafe(safe_).execTransactionFromModule(
                token0, 0, payload, Operation.Call
            );
        }

        if (amount1_ > 0) {
            uint256 amountToTransfer =
                amount1_ > balance1 ? balance1 : amount1_;
            balance1 -= amountToTransfer;
            payload = abi.encodeWithSelector(
                IERC20.transfer.selector, receiver_, amountToTransfer
            );

            ISafe(safe_).execTransactionFromModule(
                token1, 0, payload, Operation.Call
            );
        }

        // #endregion transfer amount0 and amount1 to receiver.

        // #region check if safe is a depositor and whitelist it if neccesary.

        bool isDepositor;

        {
            address[] memory depositors =
                IArrakisMetaVaultPrivate(vault_).depositors();

            uint256 length = depositors.length;

            for (uint256 i = 0; i < length;) {
                if (depositors[i] == safe_) {
                    isDepositor = true;
                    break;
                }

                unchecked {
                    i += 1;
                }
            }
        }

        if (!isDepositor) {
            address[] memory depositors = new address[](1);
            depositors[0] = safe_;

            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.whitelistDepositors.selector,
                depositors
            );

            ISafe(safe_).execTransactionFromModule(
                vault_, 0, payload, Operation.Call
            );
        }

        // #endregion check if safe is a depositor and whitelist it if neccesary.

        // #region deposit left over.

        if (balance0 > 0 || balance1 > 0) {
            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.deposit.selector,
                balance0,
                balance1
            );

            ISafe(safe_).execTransactionFromModule(
                vault_, 0, payload, Operation.Call
            );
        }

        // #endregion deposit left over.
    }
}
