// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";
import {UniswapV3StandardModule} from
    "../abstracts/UniswapV3StandardModule.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract UniswapV3StandardModulePrivate is
    UniswapV3StandardModule,
    IArrakisLPModulePrivate
{
    using Address for address payable;
    using SafeERC20 for IERC20Metadata;

    // #region public constants.

    /// @dev id = keccak256(abi.encode("UniswapV3StandardModulePrivate"))
    bytes32 public constant id =
        0xdd8e5ba3a291a21cb84e292884a78825d22f136e8932aeae51d2e181fe6378ec;

    // #endregion public constants.

    constructor(
        address guardian_,
        address factory_
    ) UniswapV3StandardModule(guardian_, factory_) {}

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

        if(msg.value > 0) revert NativeCoinNotSupported();

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
            token0.safeTransferFrom(
                depositor_, address(this), amount0_
            );
        }

        if (amount1_ > 0) {
            token1.safeTransferFrom(
                depositor_, address(this), amount1_
            );
        }
    }

    // #endregion internal functions.
}
