// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModule} from "../../src/interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePublic} from "../../src/interfaces/IArrakisLPModulePublic.sol";
import {IArrakisMetaVault} from "../../src/interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../../src/interfaces/IOracleWrapper.sol";
import {PIPS} from "../../src/constants/CArrakis.sol";

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ModuleMock is
    IArrakisLPModule,
    IArrakisLPModulePublic,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    // #region errors.

    error NoNativeToken();

    // #endregion errors.

    // #region public properties.

    IArrakisMetaVault public metaVault;
    IERC20 public token0;
    IERC20 public token1;

    // #endregion public properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;
    address internal _guardian;

    // #endregion internal properties.

    // #region mock internal properties.

    address internal _manager;
    address internal _pauser;
    uint256 internal _managerBalance0;
    uint256 internal _managerBalance1;
    uint256 internal _managerFeePIPS;

    // #endregion mock internal properties.

    // #region modifiers.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault))
            revert OnlyMetaVault(msg.sender, address(metaVault));
        _;
    }

    modifier onlyManager() {
        if (_manager != msg.sender) revert OnlyManager(msg.sender, _manager);
        _;
    }

    modifier onlyGuardian() {
        if (_pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    // #endregion modifiers.

    function initialize(
        address metaVault_,
        uint256 init0_,
        uint256 init1_,
        address guardian_,
        uint256 managerFeePIPS_
    ) external initializer {
        __Pausable_init();
        __ReentrancyGuard_init();
        metaVault = IArrakisMetaVault(metaVault_);

        token0 = IERC20(metaVault.token0());
        token1 = IERC20(metaVault.token1());

        _init0 = init0_;
        _init1 = init1_;
        _guardian = guardian_;
        _managerFeePIPS = managerFeePIPS_;
    }

    // #region guardian functions.

    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    // #region external/public functions.

    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

        // #region effects.

        // #region balances token0 and token1.

        uint256 amt0 = token0.balanceOf(address(this));
        uint256 amt1 = token1.balanceOf(address(this));

        if (amt0 == 0 && amt1 == 0) {
            amt0 = _init0;
            amt1 = _init1;
        }

        amount0 = FullMath.mulDiv(proportion_, amt0, PIPS);
        amount1 = FullMath.mulDiv(proportion_, amt1, PIPS);

        // #endregion balances token0 and token1.

        // #endregion effects.

        // #region interactions.

        token0.safeTransferFrom(depositor_, address(this), amount0);
        token1.safeTransferFrom(depositor_, address(this), amount1);

        // #endregion interactions.

        emit LogDeposit(depositor_, proportion_, amount0, amount1);
    }

    function withdraw(
        address receiver_,
        uint256 proportion_
    )
        external
        onlyMetaVault
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();
        if (proportion_ > PIPS) revert ProportionGtPIPS();

        // #endregion checks.

        // #region effects.

        uint256 amt0 = token0.balanceOf(receiver_);
        uint256 amt1 = token1.balanceOf(receiver_);

        amount0 = FullMath.mulDiv(amt0, proportion_, PIPS);
        amount1 = FullMath.mulDiv(amt1, proportion_, PIPS);

        // #endregion effects.

        // #region interactions.

        if (amount0 > 0) token0.safeTransfer(receiver_, amount0);
        if (amount1 > 0) token1.safeTransfer(receiver_, amount1);

        // #endregion interactions.

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    function withdrawManagerBalance()
        external
        whenNotPaused
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = _managerBalance0;
        amount1 = _managerBalance1;
        _managerBalance0 = 0;
        _managerBalance1 = 0;
        if (amount0 > 0) token0.safeTransfer(_manager, amount0);
        if (amount1 > 0) token1.safeTransfer(_manager, amount1);
    }

    function setManagerFeePIPS(uint256 newFeePIPS_) external whenNotPaused {
        uint256 _oldFee = _managerFeePIPS;

        // #region checks.

        if (msg.sender != _manager) revert OnlyManager(msg.sender, _manager);

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_);
    }

    // #endregion external/public functions.

    // #region pure/view public functions.

    function validateRebalance(IOracleWrapper oracle_, uint24 maxDeviation_) external view {
        
    }

    function guardian() external view returns(address) {
        return _guardian;
    }

    function managerBalance0() external view returns (uint256 fees0) {
        return _managerBalance0;
    }

    function managerBalance1() external view returns (uint256 fees1) {
        return _managerBalance1;
    }

    function managerFeePIPS() external view returns (uint256) {
        return _managerFeePIPS;
    }

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return (_init0, _init1);
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = token0.balanceOf(address(this)) - _managerBalance0;
        amount1 = token1.balanceOf(address(this)) - _managerBalance1;
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        amount0 = token0.balanceOf(address(this)) - _managerBalance0;
        amount1 = token1.balanceOf(address(this)) - _managerBalance1;
    }

    // #endregion pure/view public functions.

    // #region mock functions.

    function setManagerBalance(
        uint256 managerBalance0_,
        uint256 managerBalance1_
    ) external {
        /// @dev send directly the corresponding token to the module.
        _managerBalance0 = managerBalance0_;
        _managerBalance1 = managerBalance1_;
    }

    function setManager(address manager_) external {
        _manager = manager_;
    }

    function setGuardianPauser(address pauser_) external {
        _pauser = pauser_;
    }

    // #endregion mock functions.
}
