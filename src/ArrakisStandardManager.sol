// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {IArrakisStandardManager} from
    "./interfaces/IArrakisStandardManager.sol";
import {IManager} from "./interfaces/IManager.sol";
import {SetupParams} from "./structs/SManager.sol";
import {TEN_PERCENT, PIPS, WEEK} from "./constants/CArrakis.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {VaultInfo, FeeIncrease} from "./structs/SManager.sol";
import {IGuardian} from "./interfaces/IGuardian.sol";

// #region openzeppelin dependencies.
import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {SafeERC20} from
    "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from
    "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
// #endregion openzeppelin dependencies.

// #region openzeppelin upgradeable dependencies.

import {ReentrancyGuardUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

// #endregion openzeppelin upgradeable dependencies.

// #region solady dependencies.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady dependencies.

// #region uniswap.
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";
// #endregion uniswap.

// NOTE admin and owner can't be the same address on transparent proxy.
contract ArrakisStandardManager is
    IArrakisStandardManager,
    IManager,
    Ownable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20Metadata;
    using Address for address payable;

    // #region public immutable.

    uint256 public immutable defaultFeePIPS;
    address public immutable nativeToken;
    uint8 public immutable nativeTokenDecimals;

    // #endregion public immutable.

    // #region public properties.

    address public defaultReceiver;

    mapping(address => address) public receiversByToken;
    mapping(address => VaultInfo) public vaultInfo;
    mapping(address => FeeIncrease) public pendingFeeIncrease;
    address public factory;

    // #endregion public properties.

    // #region internal properties.

    address internal immutable _guardian;
    EnumerableSet.AddressSet internal _vaults;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyVaultOwner(address vault_) {
        address o = IOwnable(vault_).owner();
        if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        _;
    }

    modifier onlyWhitelistedVault(address vault_) {
        if (!_vaults.contains(vault_)) {
            revert NotWhitelistedVault(vault_);
        }
        _;
    }

    modifier onlyGuardian() {
        address pauser = IGuardian(_guardian).pauser();
        if (msg.sender != pauser) {
            revert OnlyGuardian(msg.sender, pauser);
        }
        _;
    }

    // #endregion modifiers.

    constructor(
        uint256 defaultFeePIPS_,
        address nativeToken_,
        uint8 nativeTokenDecimals_,
        address guardian_
    ) {
        if (nativeToken_ == address(0)) revert AddressZero();
        if (nativeTokenDecimals_ == 0) {
            revert NativeTokenDecimalsZero();
        }
        if (guardian_ == address(0)) revert AddressZero();
        /// @dev we are not checking if the default fee pips is not zero, to have
        /// the option to set 0 as default fee pips.

        defaultFeePIPS = defaultFeePIPS_;
        nativeToken = nativeToken_;
        nativeTokenDecimals = nativeTokenDecimals_;
        _guardian = guardian_;

        _disableInitializers();
    }

    /// @notice function used to initialize standard manager proxy.
    /// @param owner_ address of the owner of standard manager.
    /// @param defaultReceiver_ address of the receiver of tokens (by default).
    /// @param factory_ ArrakisMetaVaultFactory contract address.
    function initialize(
        address owner_,
        address defaultReceiver_,
        address factory_
    ) external initializer {
        if (
            owner_ == address(0) || defaultReceiver_ == address(0)
                || factory_ == address(0)
        ) revert AddressZero();

        _initializeOwner(owner_);
        __ReentrancyGuard_init();
        __Pausable_init();
        defaultReceiver = defaultReceiver_;
        factory = factory_;

        emit LogSetDefaultReceiver(address(0), defaultReceiver_);
        emit LogSetFactory(factory_);
    }

    // #region owner settable functions.

    /// @notice function used to pause the manager.
    /// @dev only callable by guardian
    function pause() external whenNotPaused onlyGuardian {
        _pause();
    }

    /// @notice function used to unpause the manager.
    /// @dev only callable by guardian
    function unpause() external whenPaused onlyGuardian {
        _unpause();
    }

    /// @notice function used to set the default receiver of tokens earned.
    /// @param newDefaultReceiver_ address of the new default receiver of tokens.
    function setDefaultReceiver(address newDefaultReceiver_)
        external
        onlyOwner
    {
        if (newDefaultReceiver_ == address(0)) revert AddressZero();
        emit LogSetDefaultReceiver(
            defaultReceiver, defaultReceiver = newDefaultReceiver_
        );
    }

    /// @notice function used to set receiver of a specific token.
    /// @param vault_ address of the meta vault that contain the specific token.
    /// @param isSetReceiverToken0_ boolean if true means that receiver is for token0
    /// if not it's for token1.
    /// @param receiver_ address of the receiver of this specific token.
    function setReceiverByToken(
        address vault_,
        bool isSetReceiverToken0_,
        address receiver_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        address token = isSetReceiverToken0_
            ? address(IArrakisMetaVault(vault_).token0())
            : address(IArrakisMetaVault(vault_).token1());

        receiversByToken[token] = receiver_;

        emit LogSetReceiverByToken(token, receiver_);
    }

    /// @notice function used to decrease the fees taken by manager for a specific vault.
    /// @param vault_ address of the vault.
    /// @param newFeePIPS_ fees in pips to set on the specific vault.
    function decreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        uint256 oldFeePIPS = vaultInfo[vault_].managerFeePIPS;
        if (oldFeePIPS <= newFeePIPS_) revert NotFeeDecrease();

        vaultInfo[vault_].managerFeePIPS = newFeePIPS_;

        IArrakisLPModule(IArrakisMetaVault(vault_).module())
            .setManagerFeePIPS(newFeePIPS_);

        emit LogChangeManagerFee(vault_, newFeePIPS_);
    }

    /// @notice function used to finalize a time lock fees increase on a vault.
    /// @param vault_ address of the vault where the fees increase will be
    /// applied.
    function finalizeIncreaseManagerFeePIPS(address vault_)
        external
        onlyOwner
    {
        FeeIncrease memory pending = pendingFeeIncrease[vault_];

        if (pending.submitTimestamp == 0) revert NoPendingIncrease();
        if (block.timestamp <= pending.submitTimestamp + WEEK) {
            revert TimeNotPassed();
        }

        uint24 newFeePIPS = pending.newFeePIPS;
        delete pendingFeeIncrease[vault_];

        vaultInfo[vault_].managerFeePIPS = newFeePIPS;

        IArrakisLPModule(IArrakisMetaVault(vault_).module())
            .setManagerFeePIPS(newFeePIPS);

        emit LogChangeManagerFee(vault_, newFeePIPS);
    }

    /// @notice function used to submit a fees increase in a managed vault.
    /// @param vault_ address of the vault where fees will be increase after timeLock.
    /// @param newFeePIPS_ fees in pips to set on the specific managed vault.
    function submitIncreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        if (pendingFeeIncrease[vault_].submitTimestamp != 0) {
            revert AlreadyPendingIncrease();
        }
        if (vaultInfo[vault_].managerFeePIPS >= newFeePIPS_) {
            revert NotFeeIncrease();
        }
        pendingFeeIncrease[vault_] = FeeIncrease({
            submitTimestamp: block.timestamp,
            newFeePIPS: newFeePIPS_
        });

        emit LogIncreaseManagerFeeSubmission(vault_, newFeePIPS_);
    }

    /// @notice function used by manager to get his balance of fees earned
    /// on a vault.
    /// @param vault_ from which fees will be collected.
    /// @return amount0 amount of token0 sent to receiver_
    /// @return amount1 amount of token1 sent to receiver_
    function withdrawManagerBalance(address vault_)
        external
        onlyOwner
        nonReentrant
        whenNotPaused
        returns (uint256 amount0, uint256 amount1)
    {
        /// NOTE I removed this line bc if vault removal is a thing then we'd still want to colect on _previously whitelisted vaults_
        // if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);

        address _token0 = IArrakisMetaVault(vault_).token0();
        address _token1 = IArrakisMetaVault(vault_).token1();

        address _receiver0 = receiversByToken[address(_token0)];
        address _receiver1 = receiversByToken[address(_token1)];

        _receiver0 =
            _receiver0 == address(0) ? defaultReceiver : _receiver0;
        _receiver1 =
            _receiver1 == address(0) ? defaultReceiver : _receiver1;

        IArrakisMetaVault(vault_).module().withdrawManagerBalance();

        if (_token0 == nativeToken) {
            amount0 = address(this).balance;
            if (amount0 > 0) payable(_receiver0).sendValue(amount0);
        } else {
            amount0 = IERC20Metadata(_token0).balanceOf(address(this));
            if (amount0 > 0) {
                IERC20Metadata(_token0).safeTransfer(
                    _receiver0, amount0
                );
            }
        }

        if (_token1 == nativeToken) {
            amount1 = address(this).balance;
            if (amount1 > 0) payable(_receiver1).sendValue(amount1);
        } else {
            amount1 = IERC20Metadata(_token1).balanceOf(address(this));
            if (amount1 > 0) {
                IERC20Metadata(_token1).safeTransfer(
                    _receiver1, amount1
                );
            }
        }

        emit LogWithdrawManagerBalance(
            _receiver0, _receiver1, amount0, amount1
        );
    }

    /// @notice function used to manage vault's strategy.
    /// @param vault_ address of the vault that need a rebalance.
    /// @param payloads_ call data to do specific action of vault side.
    function rebalance(
        address vault_,
        bytes[] calldata payloads_
    )
        external
        nonReentrant
        whenNotPaused
        onlyWhitelistedVault(vault_)
    {
        VaultInfo memory info = vaultInfo[vault_];

        if (info.executor != msg.sender) revert NotExecutor();
        if (
            info.cooldownPeriod + info.lastRebalance
                >= block.timestamp
        ) {
            revert TimeNotPassed();
        }

        IArrakisLPModule module = IArrakisMetaVault(vault_).module();

        // #region get current value of the vault.

        (uint256 amount0, uint256 amount1) =
            IArrakisMetaVault(vault_).totalUnderlying();
        address token0 = IArrakisMetaVault(vault_).token0();
        uint8 token0Decimals = token0 == nativeToken
            ? nativeTokenDecimals
            : IERC20Metadata(token0).decimals();

        module.validateRebalance(info.oracle, info.maxDeviation);

        uint256 price0 = info.oracle.getPrice0();

        uint256 vaultInToken1BeforeRebalance = FullMath.mulDiv(
            amount0, price0, 10 ** token0Decimals
        ) + amount1;

        // #endregion get current value of the vault.

        uint256 _length = payloads_.length;

        for (uint256 i; i < _length; i++) {
            // #region check if the function called isn't the setManagerFeePIPS.

            bytes4 selector = bytes4(payloads_[i][:4]);

            if (
                IArrakisLPModule.setManagerFeePIPS.selector
                    == selector
            ) revert SetManagerFeeCallNotAllowed();

            // #endregion check if the function called isn't the setManagerFeePIPS.

            (bool success,) = address(module).call(payloads_[i]);

            if (!success) revert CallFailed(payloads_[i]);
        }

        // #region assertions.

        // check if the underlying protocol price has not been
        // manipulated during rebalance.
        // that can indicate a sandwich attack.
        module.validateRebalance(info.oracle, info.maxDeviation);

        (amount0, amount1) =
            IArrakisMetaVault(vault_).totalUnderlying();

        {
            uint256 vaultInToken1AfterRebalance = FullMath.mulDiv(
                amount0, price0, 10 ** token0Decimals
            ) + amount1;

            uint256 currentSlippage = vaultInToken1BeforeRebalance
                > vaultInToken1AfterRebalance
                ? FullMath.mulDiv(
                    vaultInToken1BeforeRebalance
                        - vaultInToken1AfterRebalance,
                    PIPS,
                    vaultInToken1BeforeRebalance
                )
                : FullMath.mulDiv(
                    vaultInToken1AfterRebalance
                        - vaultInToken1BeforeRebalance,
                    PIPS,
                    vaultInToken1BeforeRebalance
                );

            if (currentSlippage > info.maxSlippagePIPS) {
                revert OverMaxSlippage();
            }
        }

        vaultInfo[vault_].lastRebalance = block.timestamp;

        // #endregion assertions.

        emit LogRebalance(vault_, payloads_);
    }

    // #endregion owner settable functions.

    /// @notice function used to set a new module (strategy) for the vault.
    /// @param vault_ address of the vault the manager want to change module.
    /// @param module_ address of the new module.
    /// @param payloads_ call data to initialize position on the new module.
    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external whenNotPaused onlyWhitelistedVault(vault_) {
        if (vaultInfo[vault_].executor != msg.sender) {
            revert NotExecutor();
        }

        IArrakisMetaVault(vault_).setModule(module_, payloads_);

        emit LogSetModule(vault_, module_, payloads_);
    }

    // #region initManagements.

    /// @notice function used to init management of a meta vault.
    /// @param params_ struct containing all the data for initialize the vault.
    function initManagement(SetupParams calldata params_)
        external
        whenNotPaused
    {
        address _factory = factory;

        if (msg.sender != _factory) {
            revert OnlyFactory(msg.sender, _factory);
        }

        _initManagement(params_);

        emit LogSetManagementParams(
            params_.vault,
            address(params_.oracle),
            params_.maxSlippagePIPS,
            params_.maxDeviation,
            params_.cooldownPeriod,
            params_.executor,
            params_.stratAnnouncer
        );
    }

    /// @notice function used to update meta vault management informations.
    /// @param params_ struct containing all the data for updating the vault.
    function updateVaultInfo(SetupParams calldata params_)
        external
        whenNotPaused
        onlyWhitelistedVault(params_.vault)
        onlyVaultOwner(params_.vault)
    {
        _updateParamsChecks(params_);
        VaultInfo memory info = vaultInfo[params_.vault];

        vaultInfo[params_.vault] = VaultInfo({
            lastRebalance: info.lastRebalance,
            cooldownPeriod: params_.cooldownPeriod,
            oracle: params_.oracle,
            executor: params_.executor,
            maxDeviation: params_.maxDeviation,
            stratAnnouncer: params_.stratAnnouncer,
            maxSlippagePIPS: params_.maxSlippagePIPS,
            managerFeePIPS: info.managerFeePIPS
        });

        emit LogSetManagementParams(
            params_.vault,
            address(params_.oracle),
            params_.maxSlippagePIPS,
            params_.maxDeviation,
            params_.cooldownPeriod,
            params_.executor,
            params_.stratAnnouncer
        );
    }

    // #endregion initManagements.

    receive() external payable {}

    /// @notice function used to announce the strategy that the vault will follow.
    /// @param vault_ address of arrakis meta vault that will follow the strategy.
    /// @param strategy_ string containing the strategy name that will be used.
    function announceStrategy(
        address vault_,
        string memory strategy_
    ) external onlyWhitelistedVault(vault_) {
        // #region checks.

        VaultInfo memory info = vaultInfo[vault_];
        if (info.stratAnnouncer != msg.sender) {
            revert OnlyStratAnnouncer();
        }

        // #endregion checks.

        emit LogStrategyAnnouncement(vault_, strategy_);
    }

    // #region view public functions.

    /// @notice function used to get a list of managed vaults.
    /// @param startIndex_ starting index from which the caller want to read the array of managed vaults.
    /// @param endIndex_ ending index until which the caller want to read the array of managed vaults.
    function initializedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view whenNotPaused returns (address[] memory) {
        if (startIndex_ >= endIndex_) {
            revert StartIndexLtEndIndex(startIndex_, endIndex_);
        }

        uint256 vaultsLength = _vaults.length();
        if (endIndex_ > vaultsLength) {
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);
        }

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _vaults.at(i);
        }
        return vs;
    }

    /// @notice function used to get the number of vault under management.
    /// @param numberOfVaults number of under management vault.
    function numInitializedVaults()
        external
        view
        returns (uint256 numberOfVaults)
    {
        return _vaults.length();
    }

    /// @notice address of the pauser of manager.
    /// @return pauser address that can pause/unpause manager.
    function guardian() external view returns (address) {
        return IGuardian(_guardian).pauser();
    }

    /// @notice function used to know if a vault is under management by this manager.
    /// @param vault_ address of the meta vault the caller want to check.
    /// @return isManaged boolean which is true if the vault is under management, false otherwise.
    function isManaged(address vault_) external view returns (bool) {
        return _vaults.contains(vault_);
    }

    /// @notice function used to know the selector of initManagement functions.
    /// @param selector bytes4 defining the init management selector.
    function getInitManagementSelector()
        external
        pure
        returns (bytes4 selector)
    {
        return IArrakisStandardManager.initManagement.selector;
    }

    // #endregion view public functions.

    // #region internal functions.

    function _initManagement(SetupParams memory params_) internal {
        // #region checks.

        // check vault address is not address zero.
        if (address(params_.vault) == address(0)) {
            revert AddressZero();
        }

        // check is not already in management.
        if (_vaults.contains(params_.vault)) {
            revert AlreadyInManagement();
        }

        // check if the vault is deployed.
        if (params_.vault.code.length == 0) revert VaultNotDeployed();

        _updateParamsChecks(params_);

        // #endregion checks.

        // #region effects.

        _vaults.add(params_.vault);
        vaultInfo[params_.vault] = VaultInfo({
            lastRebalance: 0,
            oracle: params_.oracle,
            executor: params_.executor,
            stratAnnouncer: params_.stratAnnouncer,
            maxSlippagePIPS: params_.maxSlippagePIPS,
            managerFeePIPS: SafeCast.toUint24(defaultFeePIPS),
            maxDeviation: params_.maxDeviation,
            cooldownPeriod: params_.cooldownPeriod
        });

        // #endregion effects.

        // #region interactions.

        IArrakisLPModule(IArrakisMetaVault(params_.vault).module())
            .setManagerFeePIPS(defaultFeePIPS);

        // #endregion interactions.
    }

    function _updateParamsChecks(SetupParams memory params_)
        internal
        view
    {
        // check if standard manager is the vault manager.
        address manager = IArrakisMetaVault(params_.vault).manager();
        if (address(this) != manager) {
            revert NotTheManager(address(this), manager);
        }

        // check oracle is not address zero.
        if (address(params_.oracle) == address(0)) {
            revert AddressZero();
        }

        // check slippage is lower than 10%
        // TODO: let maybe remove that check?
        if (params_.maxSlippagePIPS > TEN_PERCENT) {
            revert SlippageTooHigh();
        }

        // check we have a cooldown period.
        if (params_.cooldownPeriod == 0) {
            revert CooldownPeriodSetToZero();
        }
    }
    // #endregion internal functions.
}
