// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IValantisModule} from "../interfaces/IValantisSOTModule.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {ISovereignPool} from "../interfaces/ISovereignPool.sol";
import {ISovereignALM} from "../interfaces/ISovereignALM.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {PIPS} from "../constants/CArrakis.sol";

contract ValantisModule is
    IArrakisLPModule,
    IValantisModule,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    // #region public immutable properties.

    IArrakisMetaVault public immutable metaVault;
    ISovereignPool public immutable pool;
    ISovereignALM public immutable alm;
    IERC20 public immutable token0;
    IERC20 public immutable token1;

    // #endregion public immutable properties.

    // #region internal properties.

    uint256 internal _init0;
    uint256 internal _init1;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault))
            revert OnlyMetaVault(msg.sender, address(metaVault));
        _;
    }

    modifier onlyPool() {
        if (msg.sender != address(pool))
            revert OnlyPool(msg.sender, address(pool));
        _;
    }

    // #endregion modifiers.

    // #region enums.

    enum AccessType {
        SWAP,
        DEPOSIT,
        WITHDRAW
    }

    // #endregion enums.

    constructor(
        address metaVault_,
        address pool_,
        address alm_,
        uint256 init0_,
        uint256 init1_
    ) {
        if (metaVault_ == address(0)) revert AddressZero();
        if (pool_ == address(0)) revert AddressZero();
        if (alm_ == address(0)) revert AddressZero();
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();

        metaVault = IArrakisMetaVault(metaVault_);
        pool = ISovereignPool(pool_);
        alm = ISovereignALM(alm_);

        token0 = IERC20(metaVault.token0());
        token1 = IERC20(metaVault.token1());

        _init0 = init0_;
        _init1 = init1_;
    }

    function deposit(
        address depositor_,
        uint256 proportion_
    )
        external
        payable
        onlyMetaVault
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        if (msg.value > 0) revert NoNativeToken();
        if (depositor_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = alm.getReserves();

            if (_amt0 == 0 && _amt1 == 0) {
                _amt0 = _init0;
                _amt1 = _init1;
            }

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        uint256 _liq;
        {
            uint256 totalSupply = alm.totalSupply();
            totalSupply = totalSupply == 0 ? 1e18 : totalSupply;

            _liq = FullMath.mulDiv(proportion_, totalSupply, PIPS);
        }

        // #endregion effects.

        // #region interactions.

        // #region get the tokens from the depositor.

        token0.safeTransferFrom(depositor_, address(this), amount0);
        token1.safeTransferFrom(depositor_, address(this), amount1);

        // #endregion get the tokens from the depositor.

        // #region increase allowance to alm.

        token0.safeIncreaseAllowance(address(alm), amount0);
        token1.safeIncreaseAllowance(address(alm), amount1);

        // #endregion increase allowance to alm.

        alm.depositLiquidity(
            amount0,
            amount1,
            block.timestamp,
            _liq,
            address(this),
            ""
        );

        // #endregion interactions.

        emit LogDeposit(proportion_, amount0, amount1);
    }

    function withdraw(
        address receiver_,
        uint256 proportion_
    )
        external
        onlyMetaVault
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();
        if (proportion_ == 0) revert ProportionZero();
        if (proportion_ > PIPS) revert CannotBurnMtTotalSupply();

        uint256 _liq;
        {
            uint256 totalSupply = alm.totalSupply();
            if (totalSupply == 0) revert TotalSupplyZero();

            _liq = FullMath.mulDiv(proportion_, totalSupply, PIPS);
        }

        // #endregion checks.

        // #region effects.

        {
            (uint256 _amt0, uint256 _amt1) = alm.getReserves();

            amount0 = FullMath.mulDiv(proportion_, _amt0, PIPS);
            amount1 = FullMath.mulDiv(proportion_, _amt1, PIPS);
        }

        // #endregion effects.

        // #region interactions.

        (uint256 actual0, uint256 actual1) = alm.withdrawLiquidity(
            _liq,
            amount0,
            amount1,
            block.timestamp,
            receiver_,
            ""
        );

        // #endregion interactions.

        // #region assertions.

        if (actual0 != amount0)
            revert Actual0DifferentExpected(actual0, amount0);
        if (actual1 != amount1)
            revert Actual1DifferentExpected(actual1, amount1);

        // #endregion assertions.

        emit LogWithdraw(proportion_, amount0, amount1);
    }

    function withdrawManagerBalance()
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        address manager = metaVault.manager();

        (amount0, amount1) = pool.claimPoolManagerFees(0, 0);

        // #region transfer tokens to manager.

        if (amount0 > 0) token0.safeTransfer(manager, amount0);

        if (amount1 > 0) token1.safeTransfer(manager, amount1);

        // #endregion transfer tokens to manager.

        emit LogWithdrawManagerBalance(manager, amount0, amount1);
    }

    function setManagerFeePIPS(uint256 newFeePIPS_) external {
        uint256 _oldFee = pool.poolManagerFeeBips();

        // #region checks.

        if (msg.sender != metaVault.manager())
            revert OnlyManager(msg.sender, metaVault.manager());

        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        // #endregion checks.

        pool.setPoolManagerFeeBips(newFeePIPS_ / 1e2);

        emit LogSetManagerFeePIPS(_oldFee, newFeePIPS_ / 1e2);
    }

    function setManager(address newManager_) external {
        revert NotImplemented();
    }

    function managerBalance0() external view returns (uint256) {
        return pool.feePoolManager0();
    }

    function managerBalance1() external view returns (uint256) {
        return pool.feePoolManager1();
    }

    function managerFeePIPS() external view returns (uint256) {
        return pool.poolManagerFeeBips() * 1e2;
    }

    function getInits() external view returns (uint256 init0, uint256 init1) {
        return (_init0, _init1);
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return alm.getReserves();
    }

    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return alm.getReservesAtPrice(priceX96_);
    }
}
