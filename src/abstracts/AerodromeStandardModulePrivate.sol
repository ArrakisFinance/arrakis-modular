// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {IArrakisLPModule} from "../interfaces/IArrakisLPModule.sol";
import {IArrakisLPModulePrivate} from
    "../interfaces/IArrakisLPModulePrivate.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IAerodromeStandardModulePrivate} from
    "../interfaces/IAerodromeStandardModulePrivate.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IUniswapV3Factory} from "../interfaces/IUniswapV3Factory.sol";
import {INonfungiblePositionManager} from
    "../interfaces/INonfungiblePositionManager.sol";
import {IVoter} from "../interfaces/IVoter.sol";
import {ICLGauge} from "../interfaces/ICLGauge.sol";
import {IUniswapV3Pool} from "../interfaces/IUniswapV3Pool.sol";
import {IOracleWrapper} from "../interfaces/IOracleWrapper.sol";
import {IOwnable} from "../interfaces/IOwnable.sol";
import {IGuardian} from "../interfaces/IGuardian.sol";
import {
    TEN_PERCENT,
    NATIVE_COIN,
    BASE,
    PIPS
} from "../constants/CArrakis.sol";
import {
    RebalanceParams,
    ModifyPosition
} from "../structs/SUniswapV3.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
import {LiquidityAmounts} from
    "@v3-lib-0.8/contracts/LiquidityAmounts.sol";
import {TickMath} from "@v3-lib-0.8/contracts/TickMath.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract AerodromeStandardModulePrivate is
    IArrakisLPModule,
    IArrakisLPModulePrivate,
    IAerodromeStandardModulePrivate,
    IArrakisLPModuleID,
    IERC721Receiver,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20Metadata;
    using EnumerableSet for EnumerableSet.UintSet;
    using Address for address;

    // #region constant internal variables.

    /// @dev id = keccak256(abi.encode("AerodromeStandardModulePrivate"))
    bytes32 public constant id =
        0x491defc0794897991a8e5e9fa49dcbed24fe84ee079750b1db3f4df77fb17cb5;

    address public constant AERO =
        0x940181a94A35A4569E4529A3CDfB74e38FD98631;

    // #endregion constant internal variables.

    // #region immutable internal variables.

    address internal immutable _guardian;

    // #endregion immutable internal variables.

    // #region immutable state variables.

    INonfungiblePositionManager public immutable nftPositionManager;
    IUniswapV3Factory public immutable factory;
    IVoter public immutable voter;

    // #endregion immutable state variables.

    IArrakisMetaVault public metaVault;
    IERC20Metadata public token0;
    IERC20Metadata public token1;
    IOracleWrapper public oracle;
    uint256 public managerFeePIPS;
    uint24 public maxSlippage;
    address public aeroReceiver;
    address public pool;

    // #region internal state variables.

    EnumerableSet.UintSet internal _tokenIds;
    uint256 internal _aeroManagerBalance;

    // #endregion internal state variables.

    // #region modifiers.

    modifier onlyManager() {
        address manager = metaVault.manager();
        if (manager != msg.sender) {
            revert OnlyManager(msg.sender, manager);
        }
        _;
    }

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

    modifier onlyMetaVaultOwner() {
        if (msg.sender != IOwnable(address(metaVault)).owner()) {
            revert OnlyMetaVaultOwner();
        }
        _;
    }

    // #endregion modifiers.

    constructor(
        INonfungiblePositionManager nftPositionManager_,
        IUniswapV3Factory factory_,
        IVoter voter_,
        address guardian_
    ) {
        if (
            address(nftPositionManager_) == address(0)
                || address(factory_) == address(0)
                || address(voter_) == address(0)
                || guardian_ == address(0)
        ) {
            revert AddressZero();
        }
        nftPositionManager = nftPositionManager_;
        factory = factory_;
        voter = voter_;
        _guardian = guardian_;

        _disableInitializers();
    }

    // #region ERC721 receiver.

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // #endregion ERC721 receiver.

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

    // #region initialize functions.

    function initialize(
        IOracleWrapper oracle_,
        uint24 maxSlippage_,
        address aeroReceiver_,
        int24 tickSpacing_,
        address metaVault_
    ) external initializer {
        // #region checks.

        if (
            metaVault_ == address(0) || address(oracle_) == address(0)
                || aeroReceiver_ == address(0)
        ) revert AddressZero();
        if (maxSlippage_ > TEN_PERCENT) {
            revert MaxSlippageGtTenPercent();
        }

        // #endregion checks.

        metaVault = IArrakisMetaVault(metaVault_);
        oracle = oracle_;
        maxSlippage = maxSlippage_;
        aeroReceiver = aeroReceiver_;

        address _token0 = IArrakisMetaVault(metaVault_).token0();
        address _token1 = IArrakisMetaVault(metaVault_).token1();

        if (_token0 == NATIVE_COIN || _token1 == NATIVE_COIN) {
            revert NativeCoinNotSupported();
        }

        address _pool =
            factory.getPool(_token0, _token1, tickSpacing_);

        if (_pool == address(0)) {
            revert PoolNotFound();
        }

        pool = _pool;

        token0 = IERC20Metadata(_token0);
        token1 = IERC20Metadata(_token1);

        __ReentrancyGuard_init();
        __Pausable_init();
    }

    /// @notice function used to initialize the module
    /// when a module switch happen
    function initializePosition(
        bytes calldata data_
    ) external {
        /// @dev left over will sit on the module.
    }

    // #endregion initialize functions.

    // #region rfq system.

    function approve(
        address spender_,
        uint256 amount0_,
        uint256 amount1_
    ) external nonReentrant whenNotPaused onlyMetaVaultOwner {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        _token0.forceApprove(spender_, amount0_);
        _token1.forceApprove(spender_, amount1_);

        emit LogApproval(spender_, amount0_, amount1_);
    }

    // #endregion rfq system.

    function fund(
        address depositor_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable nonReentrant onlyMetaVault whenNotPaused {
        if (msg.value != 0) {
            revert NativeCoinNotSupported();
        }

        if (amount0_ == 0 && amount1_ == 0) {
            revert AmountsZero();
        }

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

        emit LogFund(depositor_, amount0_, amount1_);
    }

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
        /// @dev decrease nft position or burn it.

        // #region checks.

        if (receiver_ == address(0)) revert AddressZero();

        if (proportion_ == 0) revert ProportionZero();

        if (proportion_ > BASE) revert ProportionGtBASE();

        // #endregion checks.

        uint256[] memory tokenIds = _tokenIds.values();

        uint256 aeroAmountCollected;

        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        amount0 = FullMath.mulDiv(
            _token0.balanceOf(address(this)), proportion_, BASE
        );
        amount1 = FullMath.mulDiv(
            _token1.balanceOf(address(this)), proportion_, BASE
        );

        (uint160 sqrtPriceX96,,,,,) = IUniswapV3Pool(pool).slot0();

        for (uint256 i; i < tokenIds.length;) {
            (uint256 amt0, uint256 amt1, uint256 aeroCo) =
            _modifyPosition(
                ModifyPosition({
                    tokenId: tokenIds[i],
                    proportion: proportion_
                }),
                sqrtPriceX96
            );

            amount0 += amt0;
            amount1 += amt1;
            aeroAmountCollected += aeroCo;

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        uint256 _managerFeePIPS = managerFeePIPS;

        _aeroManagerBalance += FullMath.mulDiv(
            aeroAmountCollected, _managerFeePIPS, PIPS
        );

        // #endregion take the manager share.

        if (amount0 > 0) {
            _token0.safeTransfer(receiver_, amount0);
        }
        if (amount1 > 0) {
            _token1.safeTransfer(receiver_, amount1);
        }

        emit LogWithdraw(receiver_, proportion_, amount0, amount1);
    }

    function claimRewards(
        address receiver_
    ) external onlyMetaVaultOwner nonReentrant whenNotPaused {
        // #region checks.

        if (receiver_ == address(0)) {
            revert AddressZero();
        }

        // #endregion checks.

        uint256 length = _tokenIds.length();
        address gauge = voter.gauges(pool);

        uint256 aeroBalance;

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            uint256 balance =
                IERC20Metadata(AERO).balanceOf(address(this));

            ICLGauge(gauge).getReward(tokenId);

            aeroBalance += IERC20Metadata(AERO).balanceOf(
                address(this)
            ) - balance;

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        _aeroManagerBalance +=
            FullMath.mulDiv(aeroBalance, managerFeePIPS, PIPS);

        // #endregion take the manager share.

        uint256 aeroToClaim = IERC20Metadata(AERO).balanceOf(
            address(this)
        ) - _aeroManagerBalance;

        IERC20Metadata(AERO).safeTransfer(receiver_, aeroToClaim);

        emit LogClaim(receiver_, aeroToClaim);
    }

    function setReceiver(
        address newReceiver_
    ) external onlyManager whenNotPaused {
        address oldReceiver = aeroReceiver;
        if (newReceiver_ == address(0)) {
            revert AddressZero();
        }

        if (oldReceiver == newReceiver_) {
            revert SameReceiver();
        }

        aeroReceiver = newReceiver_;

        emit LogSetReceiver(oldReceiver, newReceiver_);
    }

    function claimManager() public nonReentrant whenNotPaused {
        uint256 length = _tokenIds.length();
        address gauge = voter.gauges(pool);

        uint256 aeroBalance;

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            uint256 balance =
                IERC20Metadata(AERO).balanceOf(address(this));

            ICLGauge(gauge).getReward(tokenId);

            aeroBalance += IERC20Metadata(AERO).balanceOf(
                address(this)
            ) - balance;

            unchecked {
                i += 1;
            }
        }

        // #region take the manager share.

        _aeroManagerBalance +=
            FullMath.mulDiv(aeroBalance, managerFeePIPS, PIPS);

        // #endregion take the manager share.

        address _aeroReceiver = aeroReceiver;

        IERC20Metadata(AERO).safeTransfer(
            _aeroReceiver, _aeroManagerBalance
        );

        emit LogManagerClaim(_aeroReceiver, _aeroManagerBalance);
    }

    function rebalance(
        RebalanceParams calldata params_
    ) external nonReentrant whenNotPaused onlyManager {
        // #region modify postitions.

        uint256 length = params_.modifyPositions.length;

        uint256 burn0;
        uint256 burn1;

        if (length > 0) {
            uint256 aeroAmountCollected;

            (uint160 sqrtPriceX96,,,,,) = IUniswapV3Pool(pool).slot0();

            for (uint256 i; i < length;) {
                if (
                    !_tokenIds.contains(
                        params_.modifyPositions[i].tokenId
                    )
                ) {
                    revert TokenIdNotFound();
                }

                (uint256 amt0, uint256 amt1, uint256 aeroCo) =
                _modifyPosition(
                    params_.modifyPositions[i], sqrtPriceX96
                );

                burn0 += amt0;
                burn1 += amt1;
                aeroAmountCollected += aeroCo;

                unchecked {
                    i += 1;
                }
            }

            // #region manager fees.

            uint256 _managerFeePIPS = managerFeePIPS;

            _aeroManagerBalance += FullMath.mulDiv(
                aeroAmountCollected, _managerFeePIPS, PIPS
            );

            // #endregion manager fees.

            // #region minBurns.

            if (burn0 < params_.minBurn0) {
                revert BurnToken0();
            }

            if (burn1 < params_.minBurn1) {
                revert BurnToken1();
            }

            // #endregion minBurns.
        }

        // #endregion modify positions.

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

            if (params_.swapPayload.router == address(metaVault)) {
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

        // #region mint.

        length = params_.mintParams.length;

        uint256 mint0;
        uint256 mint1;

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

            if (mint0 < params_.minDeposit0) {
                revert MintToken0();
            }
            if (mint1 < params_.minDeposit1) {
                revert MintToken1();
            }
        }

        // #endregion mint.

        emit LogRebalance(burn0, burn1, mint0, mint1);
    }

    /// @notice function used by metaVault or manager to get manager fees.
    /// @return amount0 amount of token0 sent to manager.
    /// @return amount1 amount of token1 sent to manager.
    function withdrawManagerBalance()
        public
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {}

    /// @notice function used to set manager fees.
    /// @param newFeePIPS_ new fee that will be applied.
    function setManagerFeePIPS(
        uint256 newFeePIPS_
    ) external onlyManager whenNotPaused {
        uint256 _managerFeePIPS = managerFeePIPS;
        if (_managerFeePIPS == newFeePIPS_) revert SameManagerFee();
        if (newFeePIPS_ > PIPS) revert NewFeesGtPIPS(newFeePIPS_);

        claimManager();

        managerFeePIPS = newFeePIPS_;
        emit LogSetManagerFeePIPS(_managerFeePIPS, newFeePIPS_);
    }

    // #region view functions.

    /// @notice function used to get the address that can pause the module.
    /// @return guardian address of the pauser.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    function tokenIds() external view returns (uint256[] memory) {
        return _tokenIds.values();
    }

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits()
        external
        view
        returns (uint256 init0, uint256 init1)
    {}

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 length = _tokenIds.length();

        (uint160 sqrtPriceX96,,,,,) = IUniswapV3Pool(pool).slot0();

        for (uint256 i; i < length;) {
            (uint256 amt0, uint256 amt1) =
                _principal(_tokenIds.at(i), sqrtPriceX96);

            amount0 += amt0;
            amount1 += amt1;

            unchecked {
                i += 1;
            }
        }

        // #region left over.

        amount0 += token0.balanceOf(address(this));
        amount1 += token1.balanceOf(address(this));

        // #endregion left over.
    }

    /// @notice function used to get the amounts of token0 and token1 sitting
    /// on the position for a specific price.
    /// @param priceX96_ price at which we want to simulate our tokens composition
    /// @return amount0 the amount of token0 sitting on the position for priceX96.
    /// @return amount1 the amount of token1 sitting on the position for priceX96.
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        uint256 length = _tokenIds.length();

        for (uint256 i; i < length;) {
            (uint256 amt0, uint256 amt1) =
                _principal(_tokenIds.at(i), priceX96_);

            amount0 += amt0;
            amount1 += amt1;

            unchecked {
                i += 1;
            }
        }

        // #region left over.

        amount0 += token0.balanceOf(address(this));
        amount1 += token1.balanceOf(address(this));

        // #endregion left over.
    }

    /// @notice function used to validate if module state is not manipulated
    /// before rebalance.
    /// @param oracle_ oracle that will used to check internal state.
    /// @param maxDeviation_ maximum deviation allowed.
    /// rebalance can happen.
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {
        IERC20Metadata _token0 = token0;
        IERC20Metadata _token1 = token1;

        uint8 token0Decimals = _token0.decimals();
        uint8 token1Decimals = _token1.decimals();

        uint256 oraclePrice = oracle_.getPrice0();

        (uint160 sqrtPriceX96,,,,,) = IUniswapV3Pool(pool).slot0();

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

    /// @notice function used to get manager token0 balance.
    /// @dev amount of fees in token0 that manager have not taken yet.
    /// @return managerFee0 amount of token0 that manager earned.
    function managerBalance0()
        external
        view
        returns (uint256 managerFee0)
    {}

    /// @notice function used to get manager token1 balance.
    /// @dev amount of fees in token1 that manager have not taken yet.
    /// @return managerFee1 amount of token1 that manager earned.
    function managerBalance1()
        external
        view
        returns (uint256 managerFee1)
    {}

    function aeroManagerBalance() external view returns (uint256) {
        uint256 aeroBalance;
        uint256 length = _tokenIds.length();

        address gauge = voter.gauges(pool);

        for (uint256 i; i < length;) {
            uint256 tokenId = _tokenIds.at(i);

            aeroBalance += ICLGauge(gauge).rewards(tokenId);
            aeroBalance += ICLGauge(gauge).earned(address(this), tokenId);

            unchecked {
                i += 1;
            }
        }

        return _aeroManagerBalance
            + FullMath.mulDiv(aeroBalance, managerFeePIPS, PIPS);
    }

    // #endregion view functions.

    function _modifyPosition(
        ModifyPosition memory modifyPosition_,
        uint160 sqrtPriceX96_
    )
        internal
        returns (
            uint256 amount0ToSend,
            uint256 amount1ToSend,
            uint256 aeroAmountCollected
        )
    {
        // #region unstake position.

        address gauge;
        uint128 liquidity;
        {
            uint256 aeroAmountCo;

            (aeroAmountCo, gauge, liquidity) =
                _unstake(modifyPosition_.tokenId);

            aeroAmountCollected += aeroAmountCo;
        }

        // #region unstake position.

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

        (uint256 amt0, uint256 amt1) =
            nftPositionManager.decreaseLiquidity(params);

        if (modifyPosition_.proportion == BASE) {
            nftPositionManager.collect(
                INonfungiblePositionManager.CollectParams({
                    tokenId: modifyPosition_.tokenId,
                    recipient: address(this),
                    amount0Max: SafeCast.toUint128(amt0),
                    amount1Max: SafeCast.toUint128(amt1)
                })
            );

            nftPositionManager.burn(modifyPosition_.tokenId);

            _tokenIds.remove(modifyPosition_.tokenId);
        } else {
            nftPositionManager.approve(gauge, modifyPosition_.tokenId);
            ICLGauge(gauge).deposit(modifyPosition_.tokenId);
        }

        amount0ToSend += amt0;
        amount1ToSend += amt1;
    }

    function _unstake(
        uint256 tokenId_
    )
        internal
        returns (
            uint256 aeroAmountCollected,
            address gauge,
            uint128 liquidity
        )
    {
        // #region get rewards.

        {
            (,,,,,,, liquidity,,,,) =
                nftPositionManager.positions(tokenId_);

            gauge = voter.gauges(pool);
        }

        uint256 aeroBalance =
            IERC20Metadata(AERO).balanceOf(address(this));

        ICLGauge(gauge).withdraw(tokenId_);

        aeroAmountCollected += (
            IERC20Metadata(AERO).balanceOf(address(this))
                - aeroBalance
        );

        // #endregion get rewards.
    }

    function _mint(
        INonfungiblePositionManager.MintParams calldata params_,
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

        int24 tickSpacing = IUniswapV3Pool(pool).tickSpacing();

        if (params_.tickSpacing != tickSpacing) {
            revert TickSpacingMismatch();
        }

        // #region approves.

        if (params_.amount0Desired > 0) {
            IERC20Metadata(token0_).forceApprove(
                address(nftPositionManager), params_.amount0Desired
            );
        }
        if (params_.amount1Desired > 0) {
            IERC20Metadata(token1_).forceApprove(
                address(nftPositionManager), params_.amount1Desired
            );
        }

        // #endregion approves.

        (tokenId,, amount0, amount1) =
            nftPositionManager.mint(params_);

        if (params_.amount0Desired > 0) {
            IERC20Metadata(token0_).forceApprove(
                address(nftPositionManager), 0
            );
        }
        if (params_.amount1Desired > 0) {
            IERC20Metadata(token1_).forceApprove(
                address(nftPositionManager), 0
            );
        }

        _tokenIds.add(tokenId);

        // #region stake.

        address gauge = voter.gauges(pool);

        nftPositionManager.approve(gauge, tokenId);
        ICLGauge(gauge).deposit(tokenId);

        // #endregion stake.
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
        uint256 tokenId,
        uint160 sqrtRatioX96
    ) internal view returns (uint256 amount0, uint256 amount1) {
        (
            ,
            ,
            ,
            ,
            ,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            ,
            ,
            ,
        ) = nftPositionManager.positions(tokenId);

        return LiquidityAmounts.getAmountsForLiquidity(
            sqrtRatioX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            liquidity
        );
    }
}
