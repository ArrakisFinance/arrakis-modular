// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";
import {PancakeSwapV3StandardModule} from
    "../abstracts/PancakeSwapV3StandardModule.sol";
import {NATIVE_COIN} from "../constants/CArrakis.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract PancakeSwapV3StandardModulePrivate is
    PancakeSwapV3StandardModule,
    IArrakisLPModulePrivate
{
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    // #region errors.

    error InvalidMsgValue();
    error OnlyVault();

    // #endregion errors.

    // #region public constants.

    /// @dev id = keccak256(abi.encode("PancakeSwapV3StandardModulePrivate"))
    bytes32 public constant id =
        0x7cec99d521e59378e389a879513f6373dd58e86a0c1422fa01195032b7071950;

    // #endregion public constants.

    constructor(address guardian_, address factory_) PancakeSwapV3StandardModule(guardian_, factory_) {}

    /// @notice fund function for private vault.
    /// @param depositor_ address that will provide the tokens.
    /// @param amount0_ amount of token0 that depositor want to send to module.
    /// @param amount1_ amount of token1 that depositor want to send to module.
    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyMetaVault whenNotPaused nonReentrant {
        // #region checks.

        if (amount0_ == 0 && amount1_ == 0) revert DepositZero();

        // #endregion checks.

        _fund(depositor_, amount0_, amount1_);

        emit LogFund(depositor_, amount0_, amount1_);
    }

    // #region internal functions.

    function _fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) internal {
        // Transfer tokens from depositor to this contract
        if (amount0_ > 0) {
            token0.safeTransferFrom(depositor_, address(this), amount0_);
        }

        if (amount1_ > 0) {
            token1.safeTransferFrom(depositor_, address(this), amount1_);
        }
    }

    // #endregion internal functions.
}