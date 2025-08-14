// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IPancakeSwapV3StandardModule} from
    "../interfaces/IPancakeSwapV3StandardModule.sol";
import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {INonfungiblePositionManagerPancake} from
    "../interfaces/INonfungiblePositionManagerPancake.sol";
import {INonfungiblePositionManager} from
    "../interfaces/INonfungiblePositionManager.sol";
import {IUniswapV3FactoryVariant} from
    "../interfaces/IUniswapV3FactoryVariant.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {IUniswapV3PoolVariant} from
    "../interfaces/IUniswapV3PoolVariant.sol";
import {IMasterChefV3} from "../interfaces/IMasterChefV3.sol";
import {
    TEN_PERCENT,
    BASE,
    PIPS,
    NATIVE_COIN
} from "../constants/CArrakis.sol";
import {
    ModifyPosition,
    RangeData,
    Range
} from "../structs/SUniswapV3.sol";
import {
    RebalanceParams,
    MintReturnValues
} from "../structs/SPancakeSwapV3.sol";
import {UnderlyingV3} from "../libraries/UnderlyingV3.sol";

// #region v3-lib.

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";

// #endregion v3-lib.

// #region openzeppelin upgradeable.

import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// #endregion openzeppelin upgradeable.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";

// #endregion openzeppelin.

abstract contract PancakeSwapV3StandardModule is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IPancakeSwapV3StandardModule,
    IArrakisLPModule,
    IArrakisLPModuleID,
    IERC721Receiver
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;

    // #region immutable.

    /// @inheritdoc IPancakeSwapV3StandardModule
    address public immutable nftPositionManager;

    ///  @inheritdoc IPancakeSwapV3StandardModule
    address public immutable factory;

    ///  @inheritdoc IPancakeSwapV3StandardModule
    address public immutable CAKE;

    ///  @inheritdoc IPancakeSwapV3StandardModule
    address public immutable masterChefV3;

    address internal immutable _guardian;

    // #endregion immutable.

    // #region state variables.

    // #region public.

    /// @inheritdoc IPancakeSwapV3StandardModule
    uint24 public maxSlippage;

    /// @inheritdoc IPancakeSwapV3StandardModule
    address public cakeReceiver;

    /// @inheritdoc IPancakeSwapV3StandardModule
    address public pool;

    /// @inheritdoc IPancakeSwapV3StandardModule
    IOracleWrapper public oracle;

    /// @inheritdoc IArrakisLPModule
    IArrakisMetaVault public metaVault;

    /// @inheritdoc IArrakisLPModule
    uint256 public managerFeePIPS;

    /// @inheritdoc IArrakisLPModule
    IERC20Metadata public token0;

    /// @inheritdoc IArrakisLPModule
    IERC20Metadata public token1;

    // #endregion public.

    // #region internal.

    /// @notice the list of tokenIds of non fungible position.
    EnumerableSet.UintSet internal _tokenIds;
    uint256 internal _cakeManagerBalance;

    uint256 internal _init0;
    uint256 internal _init1;

    // #endregion internal.

    // #endregion state variables.

    // #region modifiers.

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (pauser != msg.sender) revert OnlyGuardian();
        _;
    }

    modifier onlyMetaVaultOwner() {
        if (msg.sender != IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }
        _;
    }

    modifier onlyMetaVault() {
        if (msg.sender != address(metaVault)) {
            revert OnlyMetaVault(msg.sender, address(metaVault));
        }
        _;
    }

    modifier onlyManager() {
        address manager = metaVault.manager();
        if (manager != msg.sender) {
            revert OnlyManager(msg.sender, manager);
        }
        _;
    }

    // #endregion modifiers.

    // #region constructor.

    constructor(
        address guardian_,
        address nftPositionManager_,
        address factory_,
        address cake_,
        address masterChefV3_
    ) {
        // #region checks.
        if (
            guardian_ == address(0)
                || nftPositionManager_ == address(0)
                || factory_ == address(0) || cake_ == address(0)
                || masterChefV3_ == address(0)
        ) {
            revert AddressZero();
        }
        // #endregion checks.

        _guardian = guardian_;
        nftPositionManager = nftPositionManager_;
        factory = factory_;
        CAKE = cake_;
        masterChefV3 = masterChefV3_;

        _disableInitializers();
    }

    // #endregion constructor.

    /// @inheritdoc IERC721Receiver
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // #region guardian functions.

    /// @inheritdoc IArrakisLPModule
    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    /// @inheritdoc IArrakisLPModule
    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    // #endregion guardian functions.

    function initialize(
        IOracleWrapper oracle_,
        uint256 init0_,
        uint256 init1_,
        uint24 maxSlippage_,
        address cakeReceiver_,
        uint24 fee_,
        address metaVault_
    ) external initializer {
        // #region checks.
        if (
            address(oracle_) == address(0)
                || cakeReceiver_ == address(0) || metaVault_ == address(0)
        ) {
            revert AddressZero();
        }
        if (maxSlippage_ > TEN_PERCENT) {
            revert MaxSlippageGtTenPercent();
        }
        if (init0_ == 0 && init1_ == 0) revert InitsAreZeros();
        // #endregion checks.

        oracle = oracle_;
        _init1 = init0_;
        _init0 = init0_;
        maxSlippage = maxSlippage_;
        cakeReceiver = cakeReceiver_;
        metaVault = IArrakisMetaVault(metaVault_);

        address _token0 = IArrakisMetaVault(metaVault_).token0();
        address _token1 = IArrakisMetaVault(metaVault_).token1();

        if (_token0 == NATIVE_COIN || _token1 == NATIVE_COIN) {
            revert NativeCoinNotAllowed();
        }

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);

        address _pool = IUniswapV3FactoryVariant(factory).getPool(
            _token0, _token1, fee_
        );

        if (_pool == address(0)) revert PoolNotFound();

        pool = _pool;

        __ReentrancyGuard_init();
        __Pausable_init();
    }

    /// @inheritdoc IArrakisLPModule
    function initializePosition(
        bytes calldata data_
    ) external virtual {
        /// @dev left over will sit on the module.
    }

    // #region rfq system.

    function approve(
        address spender_,
        address[] calldata tokens_,
        uint256[] calldata amounts_
    ) external nonReentrant whenNotPaused onlyMetaVaultOwner {
        uint256 length = tokens_.length;
        if (length != amounts_.length) {
            revert LengthsNotEqual();
        }

        for (uint256 i; i < length;) {
            address token = tokens_[i];
            uint256 amount = amounts_[i];

            if (token == address(0)) {
                revert AddressZero();
            }

            if (address(token) != NATIVE_COIN) {
                IERC20Metadata(token).forceApprove(spender_, amount);
            } else {
                revert NativeCoinNotAllowed();
            }

            unchecked {
                i += 1;
            }
        }

        emit LogApproval(spender_, tokens_, amounts_);
    }

    // #endregion rfq system.

    /// @inheritdoc IArrakisLPModule
    function withdraw(
        address receiver_,
        uint256 proportion_
    )
        public
        virtual
        nonReentrant
        onlyMetaVault
        returns (uint256 amount0, uint256 amount1)
    {
        /// @dev decrease nft position or burn it.

        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        if (proportion_ > BASE) revert ProportionGtBASE();

        // #endregion checks.

        uint256[] memory tokenIds = _tokenIds.values();

        uint256 cakeAmountCollected;

        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        // #region left overs.

        amount0 = FullMath.mulDiv(
            _token0.balanceOf(address(this)), proportion_, BASE
        );
        amount1 = FullMath.mulDiv(
            _token1.balanceOf(address(this)), proportion_, BASE
        );

        // #endregion left overs.

        ModifyPosition memory modifyPosition;

        modifyPosition.proportion = proportion_;

        uint256 fee0;
        uint256 fee1;

        for (uint256 i; i < tokenIds.length;) {
            modifyPosition.tokenId = tokenIds[i];
            (
                uint256 amt0,
                uint256 amt1,
                uint256 f0,
                uint256 f1,
                uint256 cakeCo
            ) = _decreaseLiquidity(modifyPosition);

            fee0 += f0;
            fee1 += f1;

            amount0 += amt0;
            amount1 += amt1;
            cakeAmountCollected += cakeCo;

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        uint256 _managerFeePIPS = managerFeePIPS;

        if (cakeAmountCollected > 0) {
            _cakeManagerBalance += FullMath.mulDiv(
                cakeAmountCollected, _managerFeePIPS, PIPS
            );
        }

        // #endregion take the manager share.

        // #region send manager fee.

        {
            address manager = metaVault.manager();

            if (fee0 > 0) {
                uint256 managerFee0 =
                    FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
                _token0.safeTransfer(manager, managerFee0);
                fee0 = fee0 - managerFee0;
            }
            if (fee1 > 0) {
                uint256 managerFee1 =
                    FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
                _token1.safeTransfer(manager, managerFee1);
                fee1 = fee1 - managerFee1;
            }
        }

        // #endregion send manager fee.

        amount0 = amount0 + FullMath.mulDiv(fee0, proportion_, BASE);
        amount1 = amount1 + FullMath.mulDiv(fee1, proportion_, BASE);

        if (amount0 > 0) {
            _token0.safeTransfer(receiver_, amount0);
        }
        if (amount1 > 0) {
            _token1.safeTransfer(receiver_, amount1);
        }

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function rebalance(
        RebalanceParams calldata params_
    ) external nonReentrant whenNotPaused onlyManager {
        // #region decrease positions.

        uint256 length = params_.decreasePositions.length;

        uint256 burn0;
        uint256 burn1;

        if (length > 0) {
            uint256 cakeAmountCollected;

            uint256 fee0;
            uint256 fee1;

            for (uint256 i; i < length;) {
                if (
                    !_tokenIds.contains(
                        params_.decreasePositions[i].tokenId
                    )
                ) {
                    revert TokenIdNotFound();
                }

                (
                    uint256 amt0,
                    uint256 amt1,
                    uint256 f0,
                    uint256 f1,
                    uint256 cakeCo
                ) = _decreaseLiquidity(params_.decreasePositions[i]);

                fee0 += f0;
                fee1 += f1;

                burn0 += amt0;
                burn1 += amt1;
                cakeAmountCollected += cakeCo;

                unchecked {
                    i += 1;
                }
            }

            // #region manager fees.

            uint256 _managerFeePIPS = managerFeePIPS;

            if (cakeAmountCollected > 0) {
                _cakeManagerBalance += FullMath.mulDiv(
                    cakeAmountCollected, _managerFeePIPS, PIPS
                );
            }

            // #endregion manager fees.

            // #region send manager fee.

            {
                address manager = metaVault.manager();

                IERC20Metadata _token0 = token0;
                IERC20Metadata _token1 = token1;

                if (fee0 > 0) {
                    uint256 managerFee0 =
                        FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
                    _token0.safeTransfer(manager, managerFee0);
                }
                if (fee1 > 0) {
                    uint256 managerFee1 =
                        FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
                    _token1.safeTransfer(manager, managerFee1);
                }
            }

            // #endregion send manager fee

            // #region min burns.

            if (burn0 < params_.minBurn0) {
                revert BurnToken0();
            }
            if (burn1 < params_.minBurn1) {
                revert BurnToken1();
            }

            // #endregion min burns.
        }

        // #endregion decrease positions.

        // #region swap.

        if (params_.swapPayload.amountIn > 0) {
            IERC20Metadata _token0 = token0;
            IERC20Metadata _token1 = token1;

            _checkMinReturn(
                params_.swapPayload.zeroForOne,
                params_.swapPayload.expectedMinReturn,
                params_.swapPayload.amountIn,
                _token0.decimals(),
                _token1.decimals()
            );

            uint256 balance;

            if (params_.swapPayload.zeroForOne) {
                _token0.forceApprove(
                    params_.swapPayload.router,
                    params_.swapPayload.amountIn
                );

                balance = _token1.balanceOf(address(this));
            } else {
                _token1.forceApprove(
                    params_.swapPayload.router,
                    params_.swapPayload.amountIn
                );

                balance = _token0.balanceOf(address(this));
            }

            if (
                params_.swapPayload.router == address(metaVault)
                    || params_.swapPayload.router == nftPositionManager
                    || params_.swapPayload.router == masterChefV3
                    || params_.swapPayload.router == CAKE
            ) {
                revert WrongRouter();
            }

            {
                params_.swapPayload.router.functionCall(
                    params_.swapPayload.payload
                );
            }

            if (params_.swapPayload.zeroForOne) {
                balance = _token1.balanceOf(address(this)) - balance;

                if (params_.swapPayload.expectedMinReturn > balance) {
                    revert SlippageTooHigh();
                }

                _token0.forceApprove(params_.swapPayload.router, 0);
            } else {
                balance = _token0.balanceOf(address(this)) - balance;

                if (params_.swapPayload.expectedMinReturn > balance) {
                    revert SlippageTooHigh();
                }

                _token1.forceApprove(params_.swapPayload.router, 0);
            }
        }

        // #endregion swap.

        uint256 mint0;
        uint256 mint1;

        // #region increase positions.

        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(pool).slot0();

        length = params_.increasePositions.length;
        if (length > 0) {
            uint256 cakeAmountCollected;

            uint256 fee0;
            uint256 fee1;

            MintReturnValues memory mintReturnValues;

            for (uint256 i; i < length;) {
                if (
                    !_tokenIds.contains(
                        params_.increasePositions[i].tokenId
                    )
                ) {
                    revert TokenIdNotFound();
                }

                (
                    mintReturnValues.amount0,
                    mintReturnValues.amount1,
                    mintReturnValues.fee0,
                    mintReturnValues.fee1,
                    mintReturnValues.cakeCo
                ) = _increaseLiquidity(
                    params_.increasePositions[i], sqrtPriceX96
                );

                mint0 += mintReturnValues.amount0;
                mint1 += mintReturnValues.amount1;
                fee0 += mintReturnValues.fee0;
                fee1 += mintReturnValues.fee1;
                cakeAmountCollected += mintReturnValues.cakeCo;

                unchecked {
                    i += 1;
                }
            }

            // #region manager fees.

            uint256 _managerFeePIPS = managerFeePIPS;

            if (cakeAmountCollected > 0) {
                _cakeManagerBalance += FullMath.mulDiv(
                    cakeAmountCollected, _managerFeePIPS, PIPS
                );
            }

            // #endregion manager fees.

            // #region send manager fee.

            {
                address manager = metaVault.manager();

                if (fee0 > 0) {
                    uint256 managerFee0 =
                        FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
                    token0.safeTransfer(manager, managerFee0);
                }
                if (fee1 > 0) {
                    uint256 managerFee1 =
                        FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
                    token1.safeTransfer(manager, managerFee1);
                }
            }

            // #endregion send manager fee.
        }

        // #endregion increase positions.

        // #region mint.

        length = params_.mintParams.length;

        if (length > 0) {
            address _token0 = address(token0);
            address _token1 = address(token1);

            for (uint256 i; i < length;) {
                (uint256 amount0, uint256 amount1) =
                    _mint(params_.mintParams[i], _token0, _token1);

                mint0 += amount0;
                mint1 += amount1;

                unchecked {
                    i += 1;
                }
            }
        }

        // #endregion mint.

        if (mint0 < params_.minDeposit0) {
            revert MintToken0();
        }
        if (mint1 < params_.minDeposit1) {
            revert MintToken1();
        }

        emit LogRebalance(burn0, burn1, mint0, mint1);
    }

    /// @inheritdoc IArrakisLPModule
    function withdrawManagerBalance()
        public
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        uint256[] memory tokenIds = _tokenIds.values();
        uint256 fee0;
        uint256 fee1;
        uint256 cakeAmountCollected;

        for (uint256 i; i < tokenIds.length;) {
            (
                uint256 f0,
                uint256 f1,
                uint256 cakeCo
            ) = _collectFees(tokenIds[i]);

            fee0 += f0;
            fee1 += f1;

            amount0 += amt0;
            amount1 += amt1;
            cakeAmountCollected += cakeCo;

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        uint256 _managerFeePIPS = managerFeePIPS;

        if (cakeAmountCollected > 0) {
            _cakeManagerBalance += FullMath.mulDiv(
                cakeAmountCollected, _managerFeePIPS, PIPS
            );
        }

        // #endregion take the manager share.

        // #region send manager fee.

        {
            address manager = metaVault.manager();

            if (fee0 > 0) {
                amount0 =
                    FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
                _token0.safeTransfer(manager, amount0);
            }
            if (fee1 > 0) {
                amount1 =
                    FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
                _token1.safeTransfer(manager, amount1);
            }
        }

        // #endregion send manager fee.

        emit LogWithdrawManagerBalance(amount0, amount1);
    }

    /// @inheritdoc IArrakisLPModule
    function setManagerFeePIPS(
        uint256 newFeePIPS_
    ) external onlyManager whenNotPaused {
        uint256 _managerFeePIPS = managerFeePIPS;
        if (_managerFeePIPS == newFeePIPS_) revert SameManagerFee();
        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        withdrawManagerBalance();

        managerFeePIPS = newFeePIPS_;
        emit LogSetManagerFeePIPS(_managerFeePIPS, newFeePIPS_);
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function claimManager() public nonReentrant whenNotPaused {
        uint256 length = _tokenIds.length();

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            cakeBalance += IMasterChefV3(masterChefV3).harvest(
                tokenId, address(this)
            );

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        uint256 amountToSend = _cakeManagerBalance
            + FullMath.mulDiv(cakeBalance, managerFeePIPS, PIPS);
        _cakeManagerBalance = 0;

        // #endregion take the manager share.

        address _cakeReceiver = cakeReceiver;

        IERC20Metadata(CAKE).safeTransfer(_cakeReceiver, amountToSend);

        emit LogManagerClaim(_cakeReceiver, amountToSend);
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function claimRewards(
        address receiver_
    ) external onlyMetaVaultOwner nonReentrant whenNotPaused {
        // #region checks.

        if (receiver_ == address(0)) {
            revert AddressZero();
        }

        // #endregion checks.

        uint256 length = _tokenIds.length();
        uint256 cakeBalance;

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            cakeBalance += IMasterChefV3(masterChefV3).harvest(
                tokenId, address(this)
            );

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        _cakeManagerBalance +=
            FullMath.mulDiv(cakeBalance, managerFeePIPS, PIPS);

        // #endregion take the manager share.

        uint256 cakeToClaim = IERC20Metadata(CAKE).balanceOf(
            address(this)
        ) - _cakeManagerBalance;

        IERC20Metadata(CAKE).safeTransfer(receiver_, cakeToClaim);

        emit LogClaim(receiver_, cakeToClaim);
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function setReceiver(
        address newReceiver_
    ) external whenNotPaused {
        address manager = metaVault.manager();

        if (IOwnable(manager).owner() != msg.sender) {
            revert OnlyManagerOwner();
        }

        address oldReceiver = cakeReceiver;
        if (newReceiver_ == address(0)) {
            revert AddressZero();
        }

        if (oldReceiver == newReceiver_) {
            revert SameReceiver();
        }

        cakeReceiver = newReceiver_;

        emit LogSetReceiver(oldReceiver, newReceiver_);
    }

    // #region view functions.

    /// @inheritdoc IArrakisLPModule
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function tokenIds() external view returns (uint256[] memory) {
        return _tokenIds.values();
    }

    /// @inheritdoc IArrakisLPModule
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {
        return (_init0, _init1);
    }

    /// @inheritdoc IArrakisLPModule
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(pool).slot0();

        return _totalUnderlying(sqrtPriceX96);
    }

    /// @inheritdoc IArrakisLPModule
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        return _totalUnderlying(priceX96_);
    }

    /// @inheritdoc IArrakisLPModule
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        uint8 token0Decimals = _token0.decimals();
        uint8 token1Decimals = _token1.decimals();

        uint256 oraclePrice = oracle_.getPrice0();

        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(pool).slot0();

        uint256 poolPrice;

        if (sqrtPriceX96 <= type(uint128).max) {
            poolPrice = FullMath.mulDiv(
                uint256(sqrtPriceX96) * uint256(sqrtPriceX96),
                10 ** token0Decimals,
                1 << 192
            );
        } else {
            poolPrice = FullMath.mulDiv(
                FullMath.mulDiv(
                    uint256(sqrtPriceX96),
                    uint256(sqrtPriceX96),
                    1 << 64
                ),
                10 ** token0Decimals,
                1 << 128
            );
        }

        uint256 deviation = FullMath.mulDiv(
            FullMath.mulDiv(
                poolPrice > oraclePrice
                    ? poolPrice - oraclePrice
                    : oraclePrice - poolPrice,
                10 ** token1Decimals,
                poolPrice
            ),
            PIPS,
            10 ** token1Decimals
        );

        if (deviation > maxDeviation_) revert OverMaxDeviation();
    }

    /// @inheritdoc IArrakisLPModule
    function managerBalance0()
        external
        view
        returns (uint256 managerFee0)
    {
        (managerFee0,) = _managerBalance();
    }

    /// @inheritdoc IArrakisLPModule
    function managerBalance1()
        external
        view
        returns (uint256 managerFee1)
    {
        (, managerFee1) = _managerBalance();
    }

    /// @inheritdoc IPancakeSwapV3StandardModule
    function cakeManagerBalance() external view returns (uint256) {
        uint256 cakeBalance;
        uint256 length = _tokenIds.length();

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            cakeBalance +=
                IMasterChefV3(masterChefV3).pendingCake(tokenId);

            unchecked {
                i += 1;
            }
        }

        return _cakeManagerBalance
            + FullMath.mulDiv(cakeBalance, managerFeePIPS, PIPS);
    }

    // #endregion view functions.

    // #region internal functions.

    function _totalUnderlying(
        uint160 sqrtPriceX96_
    ) internal view returns (uint256 amount0, uint256 amount1) {
        uint256 fee0;
        uint256 fee1;

        uint256 length = _tokenIds.length();

        address _pool = pool;

        for (uint256 i; i < length;) {
            RangeData memory underlying;

            {
                uint256 tokenId = _tokenIds.at(i);

                (int24 tickLower, int24 tickUpper,) =
                    _getPosition(tokenId);

                underlying = RangeData({
                    self: nftPositionManager,
                    range: Range({
                        lowerTick: tickLower,
                        upperTick: tickUpper
                    }),
                    pool: _pool
                });
            }

            (uint256 amt0, uint256 amt1, uint256 f0, uint256 f1) =
                UnderlyingV3.underlying(underlying, sqrtPriceX96_);

            fee0 += f0;
            fee1 += f1;
            amount0 += amt0;
            amount1 += amt1;

            unchecked {
                i += 1;
            }
        }

        {
            uint256 _managerFeePIPS = managerFeePIPS;

            fee0 = fee0 - FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
            fee1 = fee1 - FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
        }

        amount0 = amount0 + fee0;
        amount1 = amount1 + fee1;
    }

    function _managerBalance()
        internal
        view
        returns (uint256 managerFee0, uint256 managerFee1)
    {
        uint256 fee0;
        uint256 fee1;

        uint256 length = _tokenIds.length();

        address _pool = pool;

        (uint160 sqrtPriceX96,,,,,,) =
            IUniswapV3PoolVariant(_pool).slot0();

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            (int24 tickLower, int24 tickUpper,) =
                _getPosition(tokenId);

            RangeData memory underlying = RangeData({
                self: nftPositionManager,
                range: Range({lowerTick: tickLower, upperTick: tickUpper}),
                pool: _pool
            });

            (,, uint256 f0, uint256 f1) =
                UnderlyingV3.underlying(underlying, sqrtPriceX96);

            fee0 += f0;
            fee1 += f1;

            unchecked {
                i += 1;
            }
        }

        uint256 _managerFeePIPS = managerFeePIPS;

        managerFee0 = FullMath.mulDiv(fee0, _managerFeePIPS, PIPS);
        managerFee1 = FullMath.mulDiv(fee1, _managerFeePIPS, PIPS);
    }

    function _decreaseLiquidity(
        ModifyPosition memory modifyPosition_
    )
        internal
        returns (
            uint256 burn0,
            uint256 burn1,
            uint256 fee0,
            uint256 fee1,
            uint256 cakeAmountCollected
        )
    {
        // #region unstake position.

        {
            uint128 liquidity;
            (cakeAmountCollected, liquidity) =
                _unstake(modifyPosition_.tokenId);

            liquidity = SafeCast.toUint128(
                FullMath.mulDiv(
                    liquidity, modifyPosition_.proportion, BASE
                )
            );

            INonfungiblePositionManager.DecreaseLiquidityParams memory
                params = INonfungiblePositionManager
                    .DecreaseLiquidityParams({
                    tokenId: modifyPosition_.tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: type(uint256).max
                });

            (burn0, burn1) = INonfungiblePositionManager(
                nftPositionManager
            ).decreaseLiquidity(params);
        }

        (uint256 amount0ToSend, uint256 amount1ToSend) =
        INonfungiblePositionManager(nftPositionManager).collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: modifyPosition_.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        fee0 = amount0ToSend - burn0;
        fee1 = amount1ToSend - burn1;

        if (modifyPosition_.proportion == BASE) {
            INonfungiblePositionManager(nftPositionManager).burn(
                modifyPosition_.tokenId
            );

            _tokenIds.remove(modifyPosition_.tokenId);
        } else {
            /// @dev stake the nft position.
            IERC721(nftPositionManager).transferFrom(
                address(this), masterChefV3, modifyPosition_.tokenId
            );
        }
    }

    function _increaseLiquidity(
        ModifyPosition memory modifyPosition_,
        uint160 sqrtPriceX96_
    )
        internal
        returns (
            uint256 amount0Sent,
            uint256 amount1Sent,
            uint256 fee0,
            uint256 fee1,
            uint256 cakeAmountCollected
        )
    {
        // #region increase liquidity.

        uint256 amt0;
        uint256 amt1;

        {
            (amt0, amt1) =
                _principal(modifyPosition_.tokenId, sqrtPriceX96_);
        }

        {
            (cakeAmountCollected,) = _unstake(modifyPosition_.tokenId);
        }

        // #region collect fees.

        (fee0, fee1) = INonfungiblePositionManager(nftPositionManager)
            .collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: modifyPosition_.tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // #endregion collect fees.

        amt0 = SafeCast.toUint128(
            FullMath.mulDiv(amt0, modifyPosition_.proportion, BASE)
        );
        amt1 = SafeCast.toUint128(
            FullMath.mulDiv(amt1, modifyPosition_.proportion, BASE)
        );

        {
            INonfungiblePositionManager.IncreaseLiquidityParams memory
                params = INonfungiblePositionManager
                    .IncreaseLiquidityParams({
                    tokenId: modifyPosition_.tokenId,
                    amount0Desired: amt0,
                    amount1Desired: amt1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: type(uint256).max
                });

            // #region approves.

            IERC20Metadata _token0 = token0;
            IERC20Metadata _token1 = token1;

            if (params.amount0Desired > 0) {
                _token0.forceApprove(
                    nftPositionManager, params.amount0Desired
                );
            }
            if (params.amount1Desired > 0) {
                _token1.forceApprove(
                    nftPositionManager, params.amount1Desired
                );
            }

            // #endregion approves.

            (, amount0Sent, amount1Sent) = INonfungiblePositionManager(
                nftPositionManager
            ).increaseLiquidity(params);

            if (params.amount0Desired > 0) {
                _token0.forceApprove(nftPositionManager, 0);
            }
            if (params.amount1Desired > 0) {
                _token1.forceApprove(nftPositionManager, 0);
            }
        }

        // #endregion increase liquidity.

        IERC721(nftPositionManager).transferFrom(
            address(this), masterChefV3, modifyPosition_.tokenId
        );
    }

    function _collectFees(
        uint256 tokenId_
    )
        internal
        returns (
            uint256 fee0,
            uint256 fee1,
            uint256 cakeAmountCollected
        )
    {
        {
            (cakeAmountCollected,) = _unstake(tokenId_);
        }

        // #region collect fees.

        (fee0, fee1) = INonfungiblePositionManager(nftPositionManager)
            .collect(
            INonfungiblePositionManager.CollectParams({
                tokenId: tokenId_,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            })
        );

        // #endregion collect fees

        // #endregion increase liquidity.

        IERC721(nftPositionManager).transferFrom(
            address(this), masterChefV3, tokenId_
        );
    }

    function _unstake(
        uint256 tokenId_
    )
        internal
        returns (uint256 cakeAmountCollected, uint128 liquidity)
    {
        (,, liquidity) = _getPosition(tokenId_);
        cakeAmountCollected = IMasterChefV3(masterChefV3).withdraw(
            tokenId_, address(this)
        );
    }

    function _mint(
        INonfungiblePositionManagerPancake.MintParams calldata params_,
        address token0_,
        address token1_
    ) internal returns (uint256 amount0, uint256 amount1) {
        uint256 tokenId;

        if (params_.token0 != token0_) {
            revert Token0Mismatch();
        }
        if (params_.token1 != token1_) {
            revert Token1Mismatch();
        }

        uint24 fee = IUniswapV3Pool(pool).fee();

        if (params_.fee != fee) {
            revert FeeMismatch();
        }

        // #region approves.

        if (params_.amount0Desired > 0) {
            IERC20Metadata(token0_).forceApprove(
                nftPositionManager, params_.amount0Desired
            );
        }
        if (params_.amount1Desired > 0) {
            IERC20Metadata(token1_).forceApprove(
                nftPositionManager, params_.amount1Desired
            );
        }

        // #endregion approves.

        (tokenId,, amount0, amount1) =
        INonfungiblePositionManagerPancake(nftPositionManager).mint(
            params_
        );

        if (params_.amount0Desired > 0) {
            IERC20Metadata(token0_).forceApprove(
                nftPositionManager, 0
            );
        }
        if (params_.amount1Desired > 0) {
            IERC20Metadata(token1_).forceApprove(
                nftPositionManager, 0
            );
        }

        _tokenIds.add(tokenId);

        // #region stake.

        IERC721(nftPositionManager).transferFrom(
            address(this), masterChefV3, tokenId
        );

        // #endregion stake
    }

    function _checkMinReturn(
        bool zeroForOne_,
        uint256 expectedMinReturn_,
        uint256 amountIn_,
        uint8 decimals0_,
        uint8 decimals1_
    ) internal view {
        if (zeroForOne_) {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_, 10 ** decimals0_, amountIn_
                )
                    < FullMath.mulDiv(
                        oracle.getPrice0(), PIPS - maxSlippage, PIPS
                    )
            ) revert ExpectedMinReturnTooLow();
        } else {
            if (
                FullMath.mulDiv(
                    expectedMinReturn_, 10 ** decimals1_, amountIn_
                )
                    < FullMath.mulDiv(
                        oracle.getPrice1(), PIPS - maxSlippage, PIPS
                    )
            ) revert ExpectedMinReturnTooLow();
        }
    }

    function _principal(
        uint256 tokenId_,
        uint160 sqrtRatioX96_
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (int24 tickLower, int24 tickUpper, uint128 liquidity) =
            _getPosition(tokenId_);

        (amount0, amount1) = LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96_,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }

    /// @dev trick to workaround stack too deep.
    function _getPosition(
        uint256 tokenId_
    )
        internal
        view
        returns (int24 tickLower, int24 tickUpper, uint128 liquidity)
    {
        bytes memory payload = abi.encodeWithSelector(
            INonfungiblePositionManagerPancake.positions.selector,
            tokenId_
        );

        bytes memory result =
            address(nftPositionManager).functionStaticCall(payload);

        (,,,,, tickLower, tickUpper, liquidity) = abi.decode(
            result,
            (
                uint96,
                address,
                address,
                address,
                uint24,
                int24,
                int24,
                uint128
            )
        );
    }

    // #endregion internal functions.
}
