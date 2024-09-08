// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IBunkerModule} from "../interfaces/IBunkerModule.sol";
import {BASE} from "../constants/CArrakis.sol";

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract BunkerModule is
    IArrakisLPModule,
    IBunkerModule,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20Metadata;

    // #region public properties.

    IArrakisMetaVault public metaVault;
    IERC20Metadata public token0;
    IERC20Metadata public token1;

    // #endregion public properties.

    // #region internal immutables.

    address internal immutable _guardian;

    // #endregion internal immutables.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault)) {
            revert OnlyMetaVault(msg.sender, address(metaVault));
        }
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    constructor(address guardian_) {
        if (guardian_ == address(0)) revert AddressZero();

        _guardian = guardian_;

        _disableInitializers();
    }

    /// @notice initialize function to delegate call onced the beacon proxy is deployed,
    /// for initializing the bunker module.
    /// @param metaVault_ address of the meta vault
    function initialize(address metaVault_) external initializer {
        if (metaVault_ == address(0)) revert AddressZero();

        metaVault = IArrakisMetaVault(metaVault_);

        token0 = IERC20Metadata(metaVault.token0());
        token1 = IERC20Metadata(metaVault.token1());

        __Pausable_init();
        __ReentrancyGuard_init();
    }

    // #region guardian functions.

    /// @notice function used to pause the module.
    /// @dev only callable by guardian
    function pause() external onlyGuardian {
        _pause();
    }

    /// @notice function used to unpause the module.
    /// @dev only callable by guardian
    function unpause() external onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function initializePosition(bytes calldata) external {
        revert NotImplemented();
    }

    /// @notice function used by metaVault to withdraw tokens from the strategy.
    /// @param receiver_ address that will receive tokens.
    /// @param proportion_ the proportion of the total position that need to be withdrawn.
    /// @return amount0 amount of token0 withdrawn.
    /// @return amount1 amount of token1 withdrawn.
    function withdraw(
        address receiver_,
        uint256 proportion_
    )
        public
        virtual
        onlyMetaVault
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();
        if (proportion_ > BASE) revert ProportionGtBASE();

        // #endregion checks.

        // #region effects.

        {
            uint256 _amt0 = token0.balanceOf(address(this));
            uint256 _amt1 = token1.balanceOf(address(this));

            amount0 = FullMath.mulDiv(proportion_, _amt0, BASE);
            amount1 = FullMath.mulDiv(proportion_, _amt1, BASE);
        }

        if (amount0 == 0 && amount1 == 0) revert AmountsZeros();

        // #endregion effects.

        // #region interactions.

        if (amount0 > 0) {
            token0.safeTransfer(receiver_, amount0);
        }
        if (amount1 > 0) {
            token1.safeTransfer(receiver_, amount1);
        }

        // #endregion interactions.

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return (0, 0);
    }

    /// @notice function used to set manager fees.
    function setManagerFeePIPS(uint256) external {
        revert NotImplemented();
    }

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return fees0 amount of token0 that manager earned.
    function managerBalance0()
        external
        view
        returns (uint256 fees0)
    {
        revert NotImplemented();
    }

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return fees1 amount of token1 that manager earned.
    function managerBalance1()
        external
        view
        returns (uint256 fees1)
    {
        revert NotImplemented();
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    function validateRebalance(
        IOracleWrapper,
        uint24
    ) external view {
        revert NotImplemented();
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160
    ) external view returns (uint256 amount0, uint256 amount1) {
        revert NotImplemented();
    }

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = token0.balanceOf(address(this));
        amount1 = token1.balanceOf(address(this));
    }

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {
        revert NotImplemented();
    }

    /// @notice function used to get manager fees.
    /// @return managerFeePIPS amount of token1 that manager earned.
    function managerFeePIPS() external view returns (uint256) {
        revert NotImplemented();
    }

    // #region view functions.

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    // #endregion view functions.
}
