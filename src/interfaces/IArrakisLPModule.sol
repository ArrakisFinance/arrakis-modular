// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IArrakisMetaVault} from "./IArrakisMetaVault.sol";
import {IOracleWrapper} from "./IOracleWrapper.sol";

/// @title Liquidity providing module interface.
/// @author Arrakis Finance
/// @notice Module interfaces, modules are implementing differents strategies that an
/// arrakis module can use.
interface IArrakisLPModule {
    // #region errors.

    /// @dev triggered when an address that should not
    /// be zero is equal to address zero.
    error AddressZero();

    /// @dev triggered when the caller is different than
    /// the metaVault that own this module.
    error OnlyMetaVault(address caller, address metaVault);

    /// @dev triggered when the caller is different than
    /// the manager defined by the metaVault.
    error OnlyManager(address caller, address manager);

    /// @dev triggered if proportion of minting or burning is
    /// zero.
    error ProportionZero();

    /// @dev triggered if during withdraw more than 100% of the
    /// position.
    error ProportionGtBASE();

    /// @dev triggered when manager want to set his more
    /// earned by the position than 100% of fees earned.
    error NewFeesGtPIPS(uint256 newFees);

    /// @dev triggered when manager is setting the same fees
    /// that already active.
    error SameManagerFee();

    /// @dev triggered when inits values are zeros.
    error InitsAreZeros();

    /// @dev triggered when pause/unpaused function is
    /// called by someone else than guardian.
    error OnlyGuardian();

    // #endregion errors.

    // #region events.

    /// @notice Event describing a withdrawal of participation by an user inside this module.
    /// @dev withdraw action can be indexed by receiver.
    /// @param receiver address that will receive the tokens withdrawn.
    /// @param proportion percentage of the current position that user want to withdraw.
    /// @param amount0 amount of token0 send to "receiver" due to withdraw action.
    /// @param amount1 amount of token1 send to "receiver" due to withdraw action.
    event LogWithdraw(
        address indexed receiver,
        uint256 proportion,
        uint256 amount0,
        uint256 amount1
    );

    /// @notice Event describing a manager fee withdrawal.
    /// @param manager address of the manager that will fees earned due to his fund management.
    /// @param amount0 amount of token0 that manager has earned and will be transfered.
    /// @param amount1 amount of token1 that manager has earned and will be transfered.
    event LogWithdrawManagerBalance(
        address manager, uint256 amount0, uint256 amount1
    );

    /// @notice Event describing manager set his fees.
    /// @param oldFee fees share that have been taken by manager.
    /// @param newFee fees share that have been taken by manager.
    event LogSetManagerFeePIPS(uint256 oldFee, uint256 newFee);

    // #endregion events.

    /// @notice function used to pause the module.
    /// @dev only callable by guardian
    function pause() external;

    /// @notice function used to unpause the module.
    /// @dev only callable by guardian
    function unpause() external;

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ number of share needed to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1);

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to set manager fees.
    /// @param newFeePIPS_ new fee that will be applied.
    function setManagerFeePIPS(uint256 newFeePIPS_) external;

    // #region view functions.

    /// @notice function used to get metaVault as IArrakisMetaVault.
    /// @return metaVault that implement IArrakisMetaVault.
    function metaVault() external view returns (IArrakisMetaVault);

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address);

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return managerBalance0 amount of token0 that manager earned.
    function managerBalance0() external view returns (uint256);

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return managerBalance1 amount of token1 that manager earned.
    function managerBalance1() external view returns (uint256);

    /// @notice function used to get manager fees.
    /// @return managerFeePIPS amount of token1 that manager earned.
    function managerFeePIPS() external view returns (uint256);

    /// @notice function used to get token0 as IERC20Metadata.
    /// @return token0 as IERC20Metadata.
    function token0() external view returns (IERC20Metadata);

    /// @notice function used to get token0 as IERC20Metadata.
    /// @return token1 as IERC20Metadata.
    function token1() external view returns (IERC20Metadata);

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1);

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(uint160 priceX96_)
        external
        view
        returns (uint256 amount0, uint256 amount1);

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// @param oracle_ oracle that will used to check internal state.
    /// @param maxDeviation_ maximum deviation allowed.
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view;

    // #endregion view function.
}
