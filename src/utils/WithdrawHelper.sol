// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IWithdrawHelper} from "../interfaces/IWithdrawHelper.sol";
import {ISafe, Operation} from "../interfaces/ISafe.sol";
import {IArrakisMetaVaultPrivate} from
    "../interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {BASE, NATIVE_COIN} from "../constants/CArrakis.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/// @title Helper contract to withdraw funds from a vault at any ratio.
contract WithdrawHelper is IWithdrawHelper {
    using Address for address payable;

    /// @inheritdoc IWithdrawHelper
    function withdraw(
        address safe_,
        address vault_,
        uint256 amount0_,
        uint256 amount1_,
        address payable receiver_
    ) external override {
        // #region checks.

        if (msg.sender != safe_) {
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

            uint256 proportion0 = total0 > 0 ?
                FullMath.mulDiv(amount0_, BASE, total0) : 0;
            uint256 proportion1 = total1 > 0 ?
                FullMath.mulDiv(amount1_, BASE, total1) : 0;

            proportion =
                proportion0 > proportion1 ? proportion0 : proportion1;
        }

        // #endregion get underlying.

        // #region balance of safe.

        address token0 = IArrakisMetaVault(vault_).token0();
        address token1 = IArrakisMetaVault(vault_).token1();

        uint256 balance0;
        uint256 balance1;

        if (token0 == NATIVE_COIN) {
            balance0 = safe_.balance;
        } else {
            balance0 = IERC20(token0).balanceOf(safe_);
        }

        if (token1 == NATIVE_COIN) {
            balance1 = safe_.balance;
        } else {
            balance1 = IERC20(token1).balanceOf(safe_);
        }

        // #endregion balance of safe.

        // #region withdraw liquidity.

        {
            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.withdraw.selector,
                proportion,
                safe_
            );

            bool success = ISafe(safe_).execTransactionFromModule(
                vault_, 0, payload, Operation.Call
            );

            if (!success) {
                revert WithdrawErr();
            }
        }

        // #endregion withdraw liquidity.

        if (token0 == NATIVE_COIN) {
            balance0 = safe_.balance - balance0;
        } else {
            balance0 = IERC20(token0).balanceOf(safe_) - balance0;
        }

        if (token1 == NATIVE_COIN) {
            balance1 = safe_.balance - balance1;
        } else {
            balance1 = IERC20(token1).balanceOf(safe_) - balance1;
        }

        // #region transfer amount0 and amount1 to receiver.

        if (amount0_ > 0) {
            uint256 amountToTransfer =
                amount0_ > balance0 ? balance0 : amount0_;
            balance0 -= amountToTransfer;
            bool success;
            bytes memory returnData;
            if (token0 == NATIVE_COIN) {
                success = ISafe(safe_).execTransactionFromModule(
                    receiver_, amountToTransfer, "", Operation.Call
                );
            } else {
                payload = abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    receiver_,
                    amountToTransfer
                );

                (success, returnData) = ISafe(safe_)
                    .execTransactionFromModuleReturnData(
                    token0, 0, payload, Operation.Call
                );
            }

            if (!success) {
                revert Transfer0Err();
            }

            if (returnData.length > 0) {
                bool transferSuccessful =
                    abi.decode(returnData, (bool));

                if (!transferSuccessful) {
                    revert Transfer0Err();
                }
            }
        }

        if (amount1_ > 0) {
            uint256 amountToTransfer =
                amount1_ > balance1 ? balance1 : amount1_;
            balance1 -= amountToTransfer;
            bool success;
            bytes memory returnData;
            if (token1 == NATIVE_COIN) {
                success = ISafe(safe_).execTransactionFromModule(
                    receiver_, amountToTransfer, "", Operation.Call
                );
            } else {
                payload = abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    receiver_,
                    amountToTransfer
                );

                (success, returnData) = ISafe(safe_)
                    .execTransactionFromModuleReturnData(
                    token1, 0, payload, Operation.Call
                );
            }

            if (!success) {
                revert Transfer1Err();
            }

            if (returnData.length > 0) {
                bool transferSuccessful =
                    abi.decode(returnData, (bool));

                if (!transferSuccessful) {
                    revert Transfer1Err();
                }
            }
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

            bool success = ISafe(safe_).execTransactionFromModule(
                vault_, 0, payload, Operation.Call
            );

            if (!success) {
                revert WhitelistDepositorErr();
            }
        }

        // #endregion check if safe is a depositor and whitelist it if neccesary.

        // #region approve module.

        uint256 value;

        {
            address module =
                address(IArrakisMetaVault(vault_).module());

            if (balance0 > 0) {
                if (token0 != NATIVE_COIN) {
                    payload = abi.encodeWithSelector(
                        IERC20.approve.selector, module, balance0
                    );

                    (bool success, bytes memory returnData) = ISafe(
                        safe_
                    ).execTransactionFromModuleReturnData(
                        token0, 0, payload, Operation.Call
                    );

                    if (!success) {
                        revert Approval0Err();
                    }

                    if (returnData.length > 0) {
                        bool transferSuccessful =
                            abi.decode(returnData, (bool));

                        if (!transferSuccessful) {
                            revert Approval0Err();
                        }
                    }
                } else {
                    value = balance0;
                }
            }

            if (balance1 > 0) {
                if (token1 != NATIVE_COIN) {
                    payload = abi.encodeWithSelector(
                        IERC20.approve.selector, module, balance1
                    );

                    (bool success, bytes memory returnData) = ISafe(
                        safe_
                    ).execTransactionFromModuleReturnData(
                        token1, 0, payload, Operation.Call
                    );

                    if (!success) {
                        revert Approval1Err();
                    }

                    if (returnData.length > 0) {
                        bool transferSuccessful =
                            abi.decode(returnData, (bool));

                        if (!transferSuccessful) {
                            revert Approval1Err();
                        }
                    }
                } else {
                    value = balance1;
                }
            }
        }

        // #endregion approve module.

        // #region deposit left over.

        if (balance0 > 0 || balance1 > 0) {
            payload = abi.encodeWithSelector(
                IArrakisMetaVaultPrivate.deposit.selector,
                balance0,
                balance1
            );

            bool success = ISafe(safe_).execTransactionFromModule(
                vault_, value, payload, Operation.Call
            );

            if (!success) {
                revert DepositErr();
            }
        }

        // #endregion deposit left over.
    }
}
