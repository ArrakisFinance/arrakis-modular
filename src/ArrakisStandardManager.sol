// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisStandardManager} from "./interfaces/IArrakisStandardManager.sol";
import {SetupParams} from "./structs/SManager.sol";
import {TEN_PERCENT, PIPS, WEEK} from "./constants/CArrakis.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IOwnable} from "./interfaces/IOwnable.sol";
import {IDecimals} from "./interfaces/IDecimals.sol";
import {VaultInfo, FeeIncrease} from "./structs/SManager.sol";

// #region openzeppelin dependencies.
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
// #endregion openzeppelin dependencies.

// #region solady dependencies.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady dependencies.

// #region uniswap.
import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

// #endregion uniswap.

contract ArrakisStandardManager is
    IArrakisStandardManager,
    Ownable,
    ReentrancyGuard,
    Pausable
{
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
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

    // #endregion public properties.

    // #region internal properties.

    EnumerableSet.AddressSet internal _vaults;

    // #endregion internal properties.

    // #region modifiers.

    modifier onlyVaultOwner(address vault_) {
        address o = IOwnable(vault_).owner();
        if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        _;
    }

    modifier onlyWhitelistedVault(address vault_) {
        if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);
        _;
    }

    // #endregion modifiers.

    constructor(
        address owner_,
        address defaultReceiver_,
        uint256 defaultFeePIPS_,
        address nativeToken_,
        uint8 nativeTokenDecimals_
    ) {
        if (
            owner_ == address(0) ||
            defaultReceiver_ == address(0) ||
            nativeToken_ == address(0)
        ) revert AddressZero();
        if (nativeTokenDecimals_ == 0) revert NativeTokenDecimalsZero();
        _initializeOwner(owner_);
        defaultReceiver = defaultReceiver_;
        /// @dev we are not checking if the default fee pips is not zero, to have
        /// the option to set 0 as default fee pips.
        defaultFeePIPS = defaultFeePIPS_;

        nativeToken = nativeToken_;
        nativeTokenDecimals = nativeTokenDecimals_;

        emit LogSetDefaultReceiver(address(0), defaultReceiver_);
    }

    // #region owner settable functions.

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function setDefaultReceiver(
        address newDefaultReceiver_
    ) external onlyOwner {
        if (newDefaultReceiver_ == address(0)) revert AddressZero();
        emit LogSetDefaultReceiver(
            defaultReceiver,
            defaultReceiver = newDefaultReceiver_
        );
    }

    function setReceiverByToken(
        address vault_,
        bool isSetReceiverToken0_,
        address receiver_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        if (receiver_ == address(0)) revert AddressZero();

        address token;
        if (isSetReceiverToken0_)
            token = address(IArrakisMetaVault(vault_).token0());
        else token = address(IArrakisMetaVault(vault_).token1());

        receiversByToken[token] = receiver_;

        emit LogSetReceiverByToken(token, receiver_);
    }

    function decreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        uint256 oldFeePIPS = vaultInfo[vault_].managerFeePIPS;
        if (oldFeePIPS <= newFeePIPS_) revert NotFeeDecrease();
        /// NOTE why do we need to store it again on manager side?
        vaultInfo[vault_].managerFeePIPS = newFeePIPS_;

        IArrakisLPModule(IArrakisMetaVault(vault_).module()).setManagerFeePIPS(
            newFeePIPS_
        );

        emit LogChangeManagerFee(vault_, newFeePIPS_);
    }

    function finalizeIncreaseManagerFeePIPS(address vault_) external onlyOwner {
        FeeIncrease memory pending = pendingFeeIncrease[vault_];

        if (pending.submitTimestamp == 0) revert NoPendingIncrease();
        if (block.timestamp <= pending.submitTimestamp + WEEK)
            revert TimeNotPassed();

        /// NOTE is it cheaper? pending is already in memory.
        uint24 newFeePIPS = pending.newFeePIPS;
        delete pendingFeeIncrease[vault_];

        vaultInfo[vault_].managerFeePIPS = newFeePIPS;

        IArrakisLPModule(IArrakisMetaVault(vault_).module()).setManagerFeePIPS(
            newFeePIPS
        );

        emit LogChangeManagerFee(vault_, newFeePIPS);
    }

    function submitIncreaseManagerFeePIPS(
        address vault_,
        uint24 newFeePIPS_
    ) external onlyOwner onlyWhitelistedVault(vault_) {
        if (pendingFeeIncrease[vault_].submitTimestamp != 0)
            revert AlreadyPendingIncrease();
        if (vaultInfo[vault_].managerFeePIPS >= newFeePIPS_)
            revert NotFeeIncrease();
        pendingFeeIncrease[vault_] = FeeIncrease({
            submitTimestamp: block.timestamp,
            newFeePIPS: newFeePIPS_
        });
    }

    function withdrawManagerBalance(
        address vault_
    )
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

        _receiver0 = _receiver0 == address(0) ? defaultReceiver : _receiver0;
        _receiver1 = _receiver1 == address(0) ? defaultReceiver : _receiver1;

        IArrakisMetaVault(vault_).module().withdrawManagerBalance();

        if (_token0 == nativeToken) {
            amount0 = address(this).balance;
            if (amount0 > 0) payable(_receiver0).sendValue(amount0);
        } else {
            amount0 = IERC20(_token0).balanceOf(address(this));
            if (amount0 > 0) IERC20(_token0).safeTransfer(_receiver0, amount0);
        }

        if (_token1 == nativeToken) {
            amount1 = address(this).balance;
            if (amount1 > 0) payable(_receiver1).sendValue(amount1);
        } else {
            amount1 = IERC20(_token1).balanceOf(address(this));
            if (amount1 > 0) IERC20(_token1).safeTransfer(_receiver1, amount1);
        }

        emit LogWithdrawManagerBalance(
            _receiver0,
            _receiver1,
            amount0,
            amount1
        );
    }

    function rebalance(
        address vault_,
        bytes[] calldata payloads_
    ) external nonReentrant whenNotPaused onlyWhitelistedVault(vault_) {
        IArrakisLPModule module = IArrakisMetaVault(vault_).module();

        // #region get current value of the vault.

        (uint256 amount0, uint256 amount1) = IArrakisMetaVault(vault_)
            .totalUnderlying();
        address token0 = IArrakisMetaVault(vault_).token0();
        uint8 token0Decimals = token0 == nativeToken
            ? nativeTokenDecimals
            : IDecimals(token0).decimals();

        VaultInfo memory info = vaultInfo[vault_];

        if (info.executor != msg.sender) revert NotExecutor();
        if (info.cooldownPeriod + info.lastRebalance >= block.timestamp)
            revert TimeNotPassed();

        module.validateRebalance(info.oracle, info.maxDeviation);

        uint256 price0 = info.oracle.getPrice0();

        uint256 vaultInToken1BeforeRebalance = FullMath.mulDiv(
            amount0,
            price0,
            10 ** token0Decimals
        ) + amount1;

        // #endregion get current value of the vault.

        uint256 _length = payloads_.length;

        for (uint256 i; i < _length; i++) {
            (bool success, ) = address(module).call(payloads_[i]);

            if (!success) revert CallFailed(payloads_[i]);
        }

        // #region assertions.

        // check if the underlying protocol price has not been
        // manipulated during rebalance.
        // that can indicate a sandwich attack.
        module.validateRebalance(info.oracle, info.maxDeviation);

        (amount0, amount1) = IArrakisMetaVault(vault_).totalUnderlying();

        {
            uint256 vaultInToken1AfterRebalance = FullMath.mulDiv(
                amount0,
                price0,
                token0Decimals
            ) + amount1;

            uint256 currentSlippage = vaultInToken1BeforeRebalance >
                vaultInToken1AfterRebalance
                ? FullMath.mulDiv(
                    vaultInToken1BeforeRebalance - vaultInToken1AfterRebalance,
                    PIPS,
                    vaultInToken1BeforeRebalance
                )
                : FullMath.mulDiv(
                    vaultInToken1AfterRebalance - vaultInToken1BeforeRebalance,
                    PIPS,
                    vaultInToken1BeforeRebalance
                );

            if (currentSlippage > info.maxSlippagePIPS)
                revert OverMaxSlippage();
        }

        vaultInfo[vault_].lastRebalance = block.timestamp;

        // #endregion assertions.

        emit LogRebalance(vault_, payloads_);
    }

    // #endregion owner settable functions.

    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external whenNotPaused onlyWhitelistedVault(vault_) {
        if (vaultInfo[vault_].executor != msg.sender) revert NotExecutor();

        IArrakisMetaVault(vault_).setModule(module_, payloads_);

        emit LogSetModule(vault_, module_, payloads_);
    }

    // #region initManagements.

    function initManagement(
        SetupParams calldata params_
    ) external whenNotPaused onlyVaultOwner(params_.vault) {
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

    function updateVaultInfo(
        SetupParams calldata params_
    )
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

    // #region view public functions.

    function initializedVaults(
        uint256 startIndex_,
        uint256 endIndex_
    ) external view whenNotPaused returns (address[] memory) {
        if (startIndex_ >= endIndex_)
            revert StartIndexLtEndIndex(startIndex_, endIndex_);

        uint256 vaultsLength = _vaults.length();
        if (endIndex_ > vaultsLength)
            revert EndIndexGtNbOfVaults(endIndex_, vaultsLength);

        address[] memory vs = new address[](endIndex_ - startIndex_);
        for (uint256 i = startIndex_; i < endIndex_; i++) {
            vs[i - startIndex_] = _vaults.at(i);
        }
        return vs;
    }

    receive() external payable {}

    function numInitializedVaults() external view returns (uint256) {
        return _vaults.length();
    }

    // #endregion view public functions.

    // #region internal functions.

    function _initManagement(SetupParams memory params_) internal {
        // #region checks.

        // NOTE maybe we should check that vault is really deployed from arrakis factory ?
        // TODO add check that the vault was created through arrakis factory.

        // check vault address is not address zero.
        if (address(params_.vault) == address(0)) revert AddressZero();

        // check is not already in management.
        if (_vaults.contains(params_.vault)) revert AlreadyInManagement();

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

    function _updateParamsChecks(SetupParams memory params_) internal {
        // check if standard manager is the vault manager.
        address manager = IArrakisMetaVault(params_.vault).manager();
        if (address(this) != manager)
            revert NotTheManager(address(this), manager);

        // check oracle is not address zero.
        if (address(params_.oracle) == address(0)) revert AddressZero();

        // check slippage is lower than 10%
        if (params_.maxSlippagePIPS > TEN_PERCENT) revert SlippageTooHigh();

        // check we have a cooldown period.
        if (params_.cooldownPeriod == 0) revert CooldownPeriodSetToZero();
    }

    // #endregion internal functions.
}
