// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";
import {IArrakisLPModule} from
    "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IDopplerModule} from "../interfaces/IDopplerModule.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {DopplerData, Position} from "../structs/SDoppler.sol";
import {NATIVE_COIN, BASE} from "../constants/CArrakis.sol";
import {UnderlyingPayload, Range} from "../structs/SUniswapV4.sol";
import {UnderlyingV4} from "../libraries/UnderlyingV4.sol";
import {IDoppler} from "../interfaces/IDoppler.sol";
import {IDopplerDeployer} from "../interfaces/IDopplerDeployer.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {
    PoolId,
    PoolIdLibrary
} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {
    Currency,
    CurrencyLibrary
} from "@uniswap/v4-core/src/types/Currency.sol";
import {LPFeeLibrary} from
    "@uniswap/v4-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";
import {SqrtPriceMath} from
    "@uniswap/v4-core/src/libraries/SqrtPriceMath.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {SafeCallback} from
    "@uniswap/v4-periphery/src/base/SafeCallback.sol";

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @dev DopplerModule is a module that should only be used by private vault.
/// should not be whitelisted for public vaults.
abstract contract DopplerModule is
    IArrakisLPModulePrivate,
    IArrakisLPModule,
    IArrakisLPModuleID,
    IDopplerModule,
    SafeCallback,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20Metadata;
    using PoolIdLibrary for PoolKey;
    // #region public constants.

    /// @dev id = keccak256(abi.encode("DopplerModule"))
    bytes32 public constant override id =
        0x51a34c41c7e68691ea785ef19f0e4c7fb19b9a43bcfe396df2317ab695f4a0db;

    // #endregion public constants.

    // #region internal variables.

    address internal immutable _guardian;
    IDopplerDeployer internal immutable _dopplerDeployer;

    // #endregion internal variables.

    // #region public properties.

    IArrakisMetaVault public metaVault;
    DopplerData public dopplerData;
    bool public isInversed;
    uint24 public fee;
    int24 public tickSpacing;
    uint160 public sqrtPriceX96;
    IERC20Metadata public token0;
    IERC20Metadata public token1;
    IDoppler public doppler;
    PoolKey public poolKey;

    // #endregion public properties.

    modifier onlyMetaVault() {
        address metaVaultAddr = address(metaVault);
        if (metaVaultAddr != msg.sender) {
            revert OnlyMetaVault(msg.sender, metaVaultAddr);
        }
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    constructor(
        address poolManager_,
        address guardian_,
        address dopplerDeployer_
    ) SafeCallback(IPoolManager(poolManager_)) {
        if (guardian_ == address(0) || dopplerDeployer_ == address(0)) {
            revert AddressZero();
        }
        _guardian = guardian_;
        _dopplerDeployer = IDopplerDeployer(dopplerDeployer_);
    }

    // #region guardian functions.

    /// @notice function used to pause the module.
    /// @dev only callable by guardian
    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    /// @notice function used to unpause the module.
    /// @dev only callable by guardian
    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function initialize(
        DopplerData calldata dopplerData_,
        bool isInversed_,
        address metaVault_,
        uint24 fee_,
        int24 tickSpacing_,
        uint160 sqrtPriceX96_
    ) external initializer {
        if (metaVault_ == address(0)) revert AddressZero();
        if (fee_ > LPFeeLibrary.MAX_LP_FEE) {
            revert LPFeeLibrary.LPFeeTooLarge(fee_);
        }
        if (
            tickSpacing_ < TickMath.MIN_TICK_SPACING
                || tickSpacing_ > TickMath.MAX_TICK_SPACING
        ) {
            revert TickMath.InvalidTick(tickSpacing_);
        }
        if (sqrtPriceX96_ == 0) revert SqrtPriceMath.InvalidPrice();

        address _token0 = IArrakisMetaVault(metaVault_).token0();
        address _token1 = IArrakisMetaVault(metaVault_).token1();

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);

        isInversed = isInversed_;
        dopplerData = dopplerData_;
        metaVault = IArrakisMetaVault(metaVault_);
        fee = fee_;
        tickSpacing = tickSpacing_;
        sqrtPriceX96 = sqrtPriceX96_;

        __Pausable_init();
        __ReentrancyGuard_init();
    }

    function initializePosition(
        bytes calldata data_
    ) external {
        /// @dev we cannot switch to doppler module.
    }

    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyMetaVault whenNotPaused nonReentrant {
        if (depositor_ == address(0)) revert AddressZero();

        // #region send token to doppler.

        poolManager.unlock(abi.encode(depositor_));

        // #endregion send token to doppler.

        (uint256 amount0, uint256 amount1) = dopplerData.isToken0
            ? (dopplerData.numTokensToSell, uint256(0))
            : (uint256(0), dopplerData.numTokensToSell);

        (amount0, amount1) =
            isInversed ? (amount1, amount0) : (amount0, amount1);

        emit LogFund(depositor_, amount0, amount1);
    }

    function withdraw(
        address receiver_,
        uint256 proportion_
    ) external returns (uint256 amount0, uint256 amount1) {
        if (receiver_ == address(0)) revert AddressZero();

        // #region withdraw from doppler.

        (amount0, amount1) = doppler.migrate();

        // #endregion withdraw from doppler.

        // #region send token to receiver.

        if (isInversed) {
            (amount0, amount1) = (amount1, amount0);
        }

        token0.safeTransfer(receiver_, amount0);
        token1.safeTransfer(receiver_, amount1);

        // #region send token to receiver.

        emit LogWithdraw(receiver_, BASE, amount0, amount1);
    }

    function withdrawManagerBalance()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        return (0, 0);
    }

    function setManagerFeePIPS(
        uint256 newFeePIPS_
    ) external {
        revert NotImplemented();
    }

    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    function managerBalance0() external view returns (uint256) {
        return 0;
    }

    function managerBalance1() external view returns (uint256) {
        return 0;
    }

    function managerFeePIPS() external view returns (uint256) {
        return 0;
    }

    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {
        return (0, 0);
    }

    function totalUnderlying()
        public
        view
        returns (uint256 amount0, uint256 amount1)
    {
        DopplerData memory _dopplerData = dopplerData;
        Range[] memory ranges =
            new Range[](3 + dopplerData.numPDSlugs);

        for (uint256 i; i < 3 + dopplerData.numPDSlugs; i++) {
            Position memory position;

            (
                position.tickLower,
                position.tickUpper,
                position.liquidity,
                position.salt
            ) = doppler.positions(bytes32(uint256(i)));
            ranges[i] = Range({
                lowerTick: position.tickLower,
                upperTick: position.tickUpper,
                poolKey: poolKey
            });
        }

        (amount0, amount1,,) = UnderlyingV4.totalUnderlyingWithFees(
            UnderlyingPayload({
                ranges: ranges,
                poolManager: poolManager,
                self: address(this),
                leftOver0: 0,
                leftOver1: 0
            })
        );

        return isInversed ? (amount1, amount0) : (amount0, amount1);
    }

    function totalUnderlyingAtPrice(
        uint160
    ) external view returns (uint256 amount0, uint256 amount1) {
        return totalUnderlying();
    }

    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {
        /// @dev not implemented.
    }

    // #region internal functions.

    function _unlockCallback(
        bytes calldata data
    ) internal override returns (bytes memory) {
        address depositor = abi.decode(data, (address));

        // #region create doppler hook.

        {
            doppler = IDoppler(_dopplerDeployer.deployDoppler(
                poolManager,
                dopplerData,
                address(this)
            ));
        }

        // #endregion create doppler hook.

        // #region transfer token to doppler through poolManager.

        address tokenToSend;
        bool _isInversed = isInversed;

        if (dopplerData.isToken0) {
            if (_isInversed) {
                tokenToSend = address(token1);
            } else {
                tokenToSend = address(token0);
            }
        } else {
            if (_isInversed) {
                tokenToSend = address(token0);
            } else {
                tokenToSend = address(token1);
            }
        }

        if (tokenToSend == NATIVE_COIN) {
            poolManager.take(
                CurrencyLibrary.ADDRESS_ZERO,
                address(doppler),
                dopplerData.numTokensToSell
            );

            poolManager.sync(CurrencyLibrary.ADDRESS_ZERO);
            poolManager.settle{value: dopplerData.numTokensToSell}();
        } else {
            poolManager.take(
                Currency.wrap(tokenToSend),
                address(doppler),
                dopplerData.numTokensToSell
            );

            poolManager.sync(Currency.wrap(tokenToSend));
            IERC20Metadata(tokenToSend).safeTransfer(
                address(poolManager), dopplerData.numTokensToSell
            );
            poolManager.settle();
        }

        // #endregion transfer token to doppler through poolManager.

        // #region create pool on poolManager.

        (Currency currency0, Currency currency1) = _isInversed
            ? (
                Currency.wrap(address(token1)),
                Currency.wrap(address(token0))
            )
            : (
                Currency.wrap(address(token0)),
                Currency.wrap(address(token1))
            );

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(doppler))
        });

        poolManager.initialize(poolKey, sqrtPriceX96, "");

        // #endregion create pool on poolManager.
    }

    // #endregion internal functions.
}
