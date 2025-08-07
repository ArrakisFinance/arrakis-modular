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
import {IMasterChefV3} from "../interfaces/IMasterChefV3.sol";
import {TEN_PERCENT, BASE} from "../constants/CArrakis.sol";
import {ModifyPosition} from "../structs/SUniswapV3.sol";

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
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";

// #endregion openzeppelin upgradeable.

// #region openzeppelin.

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

// #endregion openzeppelin.

abstract contract PancakeSwapV3StandardModule is
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    IPancakeSwapV3StandardModule,
    IArrakisLPModule,
    IArrakisLPModuleID
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
        if (guardian_ == address(0)) revert AddressZero();
        if (nftPositionManager_ == address(0)) revert AddressZero();
        if (factory_ == address(0)) revert AddressZero();
        if (cake_ == address(0)) revert AddressZero();
        if (masterChefV3_ == address(0)) revert AddressZero();
        // #endregion checks.

        _guardian = guardian_;
        nftPositionManager = nftPositionManager_;
        factory = factory_;
        CAKE = cake_;
        masterChefV3 = masterChefV3_;

        _disableInitializers();
    }

    // #endregion constructor.

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
        if (address(oracle_) == address(0)) revert AddressZero();
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
    ) external {
        /// @dev left over will sit on the module.
    }

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

    /// @inheritdoc IArrakisLPModule
    function withdraw(
        address receiver_,
        uint256 proportion_
    ) external nonReentrant onlyMetaVault returns (uint256 amount0, uint256 amount1) {
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

        amount0 = FullMath.mulDiv(
            _token0.balanceOf(address(this)), proportion_, BASE
        );
        amount1 = FullMath.mulDiv(
            _token1.balanceOf(address(this)), proportion_, BASE
        );

        ModifyPosition memory modifyPosition;

        modifyPosition.proportion = proportion_;
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
        // TODO: implement.
    }

    /// @inheritdoc IArrakisLPModule
    function totalUnderlyingAtPrice(
        uint160 priceX96_
    ) external view returns (uint256 amount0, uint256 amount1) {
        // TODO: implement.
    }

    /// @inheritdoc IArrakisLPModule
    function validateRebalance(
        IOracleWrapper oracle_,
        uint24 maxDeviation_
    ) external view {
        // TODO: implement.
    }

    // #endregion view functions.

    // #region internal functions.

    function _decreaseLiquidity(
        ModifyPosition memory modifyPosition_
    )
        internal
        returns (
            uint256 amount0ToSend,
            uint256 amount1ToSend,
            uint256 fee0,
            uint256 fee1,
            uint256 cakeAmountCollected
        )
    {
        // #region unstake position.

        uint128 liquidity;
        uint256 burn0;
        uint256 burn1;
        (cakeAmountCollected, liquidity) =
            _unstake(modifyPosition_.tokenId);

        {
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

        (amount0ToSend, amount1ToSend) = INonfungiblePositionManager(
            nftPositionManager
        ).collect(
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
