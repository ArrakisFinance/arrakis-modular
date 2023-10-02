// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModuleVault} from "./interfaces/IArrakisLPModuleVault.sol";
import {IERC20, SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {FullMath} from "v3-lib-0.8/FullMath.sol";

error OnlyManager(address caller, address manager);
error OnlyModule(address caller, address module);
error ProportionGtPIPS(uint256 proportion);
error ManagerFeePIPSTooHigh(uint24 managerFeePIPS);
error FeeUpdateTooEarly(uint256 timeToUpdate);
error CallFailed();

contract ArrakisMetaVault is IArrakisMetaVault, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint24 internal constant _PIPS = 1_000_000;

    // #region internal immutable.

    uint256 internal immutable _init0;
    uint256 internal immutable _init1;

    // #endregion internal immutable.

    // #region immutable properties.

    address public immutable token0;
    address public immutable token1;

    // #endregion immutable properties.

    // #region public manager properties.

    address public manager;
    uint24 public managerFeePIPS;
    uint256 public feeDuration;
    uint256 public lastFeeUpdate;

    uint256 public managerBalance0;
    uint256 public managerBalance1;

    // #endregion public manager properties.

    // #region public properties.

    IArrakisLPModuleVault public module;

    // #endregion public properties.

    // #region transient storage.

    address internal _tokenSender;

    // #endregion transient storage.

    // #region modifier.

    modifier onlyManager() {
        if (msg.sender != manager) revert OnlyManager(msg.sender, manager);
        _;
    }

    // #endregion modifier.

    constructor(
        address token0_,
        address token1_,
        address owner_,
        uint256 init0_,
        uint256 init1_,
        address module_
    ) {
        token0 = token0_;
        token1 = token1_;
        _initializeOwner(owner_);
        _init0 = init0_;
        _init1 = init1_;
        module =IArrakisLPModuleVault(module_);
    }

    function deposit(
        uint256 proportion_
    ) external virtual onlyOwner returns (uint256 amount0, uint256 amount1) {
        _tokenSender = owner();
        (amount0, amount1) = _deposit(proportion_);
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external virtual onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _withdrawAndSend(proportion_, receiver_);
    }

    function rebalance(bytes[] calldata payloads_) external onlyManager {
        uint256 len = payloads_.length;
        for (uint256 i = 0; i < len; i++) {
            (bool success, ) = address(module).call(payloads_[i]);

            if (!success) revert CallFailed();
        }

        emit LogRebalance(payloads_);
    }

    function moduleCallback(uint256 amount0_, uint256 amount1_) external {
        if (msg.sender != address(module))
            revert OnlyModule(msg.sender, address(module));

        if (amount0_ > 0)
            IERC20(token0).safeTransferFrom(
                _tokenSender,
                address(module),
                amount0_
            );

        if (amount1_ > 0)
            IERC20(token1).safeTransferFrom(
                _tokenSender,
                address(module),
                amount1_
            );

        emit LogModuleCallback(address(module), amount0_, amount1_);
    }

    function setManager(address newManager) external onlyOwner {
        _collectFees();
        withdrawManagerBalance();

        emit LogSetManager(manager, manager = newManager);
    }

    function setManagerFeePIPS(uint24 managerFeePIPS_) external onlyManager {
        if (managerFeePIPS_ > (_PIPS / 10))
            revert ManagerFeePIPSTooHigh(managerFeePIPS_);
        if (block.timestamp < feeDuration + lastFeeUpdate)
            revert FeeUpdateTooEarly(feeDuration + lastFeeUpdate);
        _collectFees();

        emit LogSetManagerFeePIPS(
            managerFeePIPS,
            managerFeePIPS = managerFeePIPS_
        );
    }

    function withdrawManagerBalance()
        public
        returns (uint256 amount0, uint256 amount1)
    {
        amount0 = managerBalance0;
        amount1 = managerBalance1;

        managerBalance0 = 0;
        managerBalance1 = 0;

        if (amount0 > 0) IERC20(token0).safeTransfer(manager, amount0);
        if (amount1 > 0) IERC20(token1).safeTransfer(manager, amount1);

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    // #region view functions.

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return module.getInits();
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (amount0, amount1) = module.totalUnderlying();

        amount0 += IERC20(token0).balanceOf(address(this)) - managerBalance0;
        amount1 += IERC20(token1).balanceOf(address(this)) - managerBalance1;
    }

    function totalUnderlyingAtPrice(
        uint256 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module.totalUnderlyingAtPrice(priceX96_);

        amount0 += IERC20(token0).balanceOf(address(this)) - managerBalance0;
        amount1 += IERC20(token1).balanceOf(address(this)) - managerBalance1;
    }

    // #endregion view functions.

    // #region internal functions.

    function _collectFees() internal {
        // TODO: check how to deal with complete burn and mint.
        _withdraw(_PIPS);

        // #region deposit
        _tokenSender = address(this);

        uint256 token0Balance = IERC20(token0).balanceOf(address(this)) -
            managerBalance0;
        uint256 token1Balance = IERC20(token1).balanceOf(address(this)) -
            managerBalance1;
        IERC20(token0).safeIncreaseAllowance(address(module), token0Balance);
        IERC20(token1).safeIncreaseAllowance(address(module), token1Balance);

        _deposit(_PIPS);

        // #endregion deposit
    }

    function _deposit(
        uint256 proportion_
    ) internal nonReentrant returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = module.deposit(proportion_);

        emit LogDeposit(proportion_, amount0, amount1);
    }

    function _withdrawAndSend(
        uint256 proportion_,
        address receiver_
    ) internal nonReentrant returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = _withdraw(proportion_);

        if (amount0 > 0) IERC20(token0).transfer(receiver_, amount0);
        if (amount1 > 0) IERC20(token1).transfer(receiver_, amount1);

        emit LogWithdraw(proportion_, receiver_, amount0, amount1);
    }

    function _withdraw(
        uint256 proportion_
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (proportion_ > _PIPS) revert ProportionGtPIPS(proportion_);
        uint256 leftover0 = IERC20(token0).balanceOf(address(this)) -
            managerBalance0;
        uint256 leftover1 = IERC20(token1).balanceOf(address(this)) -
            managerBalance1;

        (amount0, amount1) = module.withdraw(proportion_);

        uint256 managerFees0 = FullMath.mulDiv(amount0, managerFeePIPS, _PIPS);
        uint256 managerFees1 = FullMath.mulDiv(amount1, managerFeePIPS, _PIPS);

        amount0 -= managerFees0;
        amount1 -= managerFees1;

        managerBalance0 += managerFees0;
        managerBalance1 += managerFees1;

        amount0 += FullMath.mulDiv(leftover0, proportion_, _PIPS);
        amount1 += FullMath.mulDiv(leftover1, proportion_, _PIPS);
    }

    // #endregion internal functions.
}
