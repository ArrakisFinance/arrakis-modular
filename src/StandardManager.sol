// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IManager} from "./interfaces/IManager.sol";
import {IStandardManager} from "./interfaces/IStandardManager.sol";
import {SetupParams} from "./structs/SManager.sol";
import {ERC20TYPE, NFTTYPE, TEN_PERCENT, PIPS} from "./constants/CArrakis.sol";
import {IOwnerOf} from "./interfaces/IOwnerOf.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IDecimals} from "./interfaces/IDecimals.sol";
import {VaultInfo} from "./structs/SManager.sol";

// #region openzeppelin dependencies.
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
// #endregion openzeppelin dependencies.
// #region solady dependencies.
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
// #endregion solady dependencies.
// #region uniswap.
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";

// #endregion uniswap.

contract StandardManager is IManager, IStandardManager, Ownable {
    using EnumerableSet for EnumerableSet.Bytes32Set;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // #region public immutable.

    uint256 public immutable defaultFeePIPS;
    address public immutable terms;

    // #endregion public immutable.

    // #region public properties.

    mapping(address => address) public receiversByToken;
    mapping(address => VaultInfo) public infosByVault;
    address public defaultReceiver;

    // #endregion public properties.

    // #region internal properties.

    EnumerableSet.Bytes32Set internal _strats;
    EnumerableSet.AddressSet internal _vaults;
    EnumerableSet.AddressSet internal _nftRebalancers;
    EnumerableSet.AddressSet internal _rebalancers;

    // #endregion internal properties.

    constructor(
        address owner_,
        address defaultReceiver_,
        uint256 defaultFeePIPS_,
        address terms_
    ) {
        if (
            owner_ == address(0) ||
            defaultReceiver_ == address(0) ||
            terms_ == address(0)
        ) revert AddressZero();
        _initializeOwner(owner_);
        defaultReceiver = defaultReceiver_;
        /// @dev we are not checking if the default fee pips is not zero, to have
        /// the option to set 0 as default fee pips.
        defaultFeePIPS = defaultFeePIPS_;
        terms = terms_;

        emit LogSetDefaultReceiver(address(0), defaultReceiver_);
    }

    // #region owner settable functions.

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
    ) external onlyOwner {
        if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);

        if (receiver_ == address(0)) revert AddressZero();

        address token;
        if (isSetReceiverToken0_)
            token = address(IArrakisMetaVault(vault_).token0());
        else token = address(IArrakisMetaVault(vault_).token1());

        receiversByToken[token] = receiver_;

        emit LogSetReceiverByToken(token, receiver_);
    }

    function withdrawManagerBalance(
        address vault_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);

        IERC20 _token0 = IERC20(IArrakisMetaVault(vault_).token0());
        IERC20 _token1 = IERC20(IArrakisMetaVault(vault_).token1());

        address _receiver0 = receiversByToken[address(_token0)];
        address _receiver1 = receiversByToken[address(_token1)];

        _receiver0 = _receiver0 == address(0) ? defaultReceiver : _receiver0;
        _receiver1 = _receiver1 == address(0) ? defaultReceiver : _receiver1;

        IArrakisMetaVault(vault_).module().withdrawManagerBalance();

        amount0 = _token0.balanceOf(address(this));
        amount1 = _token1.balanceOf(address(this));

        if (amount0 > 0) _token0.safeTransfer(_receiver0, amount0);

        if (amount1 > 0) _token1.safeTransfer(_receiver1, amount1);

        emit LogWithdrawManagerBalance(
            _receiver0,
            _receiver1,
            amount0,
            amount1
        );
    }

    function rebalance(address vault_, bytes[] calldata payloads_) external {
        bytes32 vaultType = IArrakisMetaVault(vault_).vaultType();
        IArrakisLPModule module = IArrakisMetaVault(vault_).module();

        if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);

        if (vaultType == ERC20TYPE) {
            if (!_rebalancers.contains(msg.sender))
                revert OnlyRebalancers(msg.sender);
        } else if (vaultType == NFTTYPE) {
            if (!_nftRebalancers.contains(msg.sender))
                revert OnlyNftRebalancers(msg.sender);
        } else {
            revert VaultTypeNotSupported(vaultType);
        }

        // #region get current value of the vault.

        (uint256 amount0, uint256 amount1) = IArrakisMetaVault(vault_)
            .totalUnderlying();
        uint8 token0Decimals = IDecimals(IArrakisMetaVault(vault_).token0())
            .decimals();

        VaultInfo memory info = infosByVault[vault_];

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

        (amount0, amount1) = IArrakisMetaVault(vault_).totalUnderlying();

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

        if (currentSlippage > info.maxSlippage) revert OverMaxSlippage();

        // #endregion assertions.

        emit LogRebalance(vault_, payloads_);
    }

    // #endregion owner settable functions.

    // #region rebalancers.

    function whitelistStrategies(
        string[] calldata strategies_
    ) external onlyOwner {
        uint256 length = strategies_.length;

        for (uint256 i; i < length; i++) {
            string memory strat = strategies_[i];
            bytes32 stratB32 = keccak256(abi.encodePacked(strat));

            if (stratB32 == keccak256(abi.encodePacked("")))
                revert EmptyString();

            if (_strats.contains(stratB32)) revert StratAlreadyWhitelisted();

            _strats.add(stratB32);
        }

        emit LogWhitelistStrategies(strategies_);
    }

    function whitelistNftRebalancers(
        address[] calldata nftRebalancers_
    ) external onlyOwner {
        uint256 _length = nftRebalancers_.length;
        if (_length == 0) revert EmptyNftRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _nftRebalancer = nftRebalancers_[i];

            if (_nftRebalancer == address(0)) revert AddressZero();

            if (_nftRebalancers.contains(_nftRebalancer))
                revert AlreadyWhitelistedNftRebalancer(_nftRebalancer);

            _nftRebalancers.add(_nftRebalancer);
        }

        emit LogWhitelistNftRebalancers(nftRebalancers_);
    }

    function whitelistRebalancers(
        address[] calldata rebalancers_
    ) external onlyOwner {
        uint256 _length = rebalancers_.length;
        if (_length == 0) revert EmptyRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _rebalancer = rebalancers_[i];

            if (_rebalancer == address(0)) revert AddressZero();

            if (_rebalancers.contains(_rebalancer))
                revert AlreadyWhitelistedRebalancer(_rebalancer);

            _rebalancers.add(_rebalancer);
        }

        emit LogWhitelistRebalancers(rebalancers_);
    }

    function blacklistNftRebalancers(
        address[] calldata nftRebalancers_
    ) external onlyOwner {
        uint256 _length = nftRebalancers_.length;
        if (_length == 0) revert EmptyNftRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _nftRebalancer = nftRebalancers_[i];

            if (_nftRebalancer == address(0)) revert AddressZero();

            if (!_nftRebalancers.contains(_nftRebalancer))
                revert NotWhitelistedNftRebalancer(_nftRebalancer);

            _nftRebalancers.remove(_nftRebalancer);
        }

        emit LogBlacklistNftRebalancers(nftRebalancers_);
    }

    function blacklistRebalancers(
        address[] calldata rebalancers_
    ) external onlyOwner {
        uint256 _length = rebalancers_.length;
        if (_length == 0) revert EmptyRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _rebalancer = rebalancers_[i];

            if (_rebalancer == address(0)) revert AddressZero();

            if (!_rebalancers.contains(_rebalancer))
                revert NotWhitelistedRebalancer(_rebalancer);

            _rebalancers.remove(_rebalancer);
        }

        emit LogBlacklistRebalancers(rebalancers_);
    }

    // #endregion rebalancers.

    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external onlyOwner {
        if (!_vaults.contains(vault_)) revert NotWhitelistedVault(vault_);

        IArrakisMetaVault(vault_).setModule(module_, payloads_);

        emit LogSetModule(vault_, module_, payloads_);
    }

    function setManagerFeePIPS(
        address[] calldata vaults_,
        uint256[] calldata feesPIPS_
    ) external onlyOwner {
        uint256 _length = vaults_.length;

        if (_length != feesPIPS_.length)
            revert NotSameLengthArray(_length, feesPIPS_.length);

        for (uint256 i; i < _length; i++) {
            address _vault = vaults_[i];
            if (!_vaults.contains(_vault)) revert NotWhitelistedVault(_vault);

            IArrakisMetaVault(_vault).module().setManagerFeePIPS(feesPIPS_[i]);
        }

        emit LogSetManagerFeePIPS(vaults_, feesPIPS_);
    }

    // #region initManagements.

    function initManagement(SetupParams calldata params_) external payable {
        bytes32 vaultType = IArrakisMetaVault(params_.vault).vaultType();

        if (vaultType == NFTTYPE) {
            address o = IOwnerOf(terms).ownerOf(params_.vault);
            if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        } else if (vaultType == ERC20TYPE) {
            if (msg.sender != owner()) revert OnlyOwner();
        } else revert VaultTypeNotSupported(vaultType);

        _initManagement(params_);

        emit LogInitManagement(
            params_.vault,
            params_.balance,
            params_.datas,
            address(params_.oracle),
            params_.maxSlippage,
            params_.maxDeviation,
            defaultFeePIPS,
            params_.coolDownPeriod,
            params_.strat
        );
    }

    function setVaultData(address vault_, bytes calldata datas_) external {
        bytes32 vaultType = IArrakisMetaVault(vault_).vaultType();

        if (vaultType == NFTTYPE) {
            address o = IOwnerOf(terms).ownerOf(vault_);
            if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        } else if (vaultType == ERC20TYPE) {
            if (msg.sender != owner()) revert OnlyOwner();
        } else revert VaultTypeNotSupported(vaultType);

        // check if the vault_ is managed.
        if (!_vaults.contains(vault_)) revert OnlyManagedVault();

        // check if the data is not already updated.

        VaultInfo memory vaultInfo = infosByVault[vault_];

        if (keccak256(vaultInfo.datas) == keccak256(datas_))
            revert DataIsUpdated();

        infosByVault[vault_].datas = datas_;

        emit LogSetVaultData(vault_, datas_);
    }

    function setVaultStratByName(
        address vault_,
        string calldata strat_
    ) external {
        bytes32 vaultType = IArrakisMetaVault(vault_).vaultType();

        if (vaultType == NFTTYPE) {
            address o = IOwnerOf(terms).ownerOf(vault_);
            if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        } else if (vaultType == ERC20TYPE) {
            if (msg.sender != owner()) revert OnlyOwner();
        } else revert VaultTypeNotSupported(vaultType);

        // check if the vault_ is managed.
        if (!_vaults.contains(vault_)) revert OnlyManagedVault();

        bytes32 _strat = keccak256(abi.encodePacked(strat_));

        if (infosByVault[vault_].strat == _strat) revert SameStrat();

        if (!_strats.contains(_strat)) revert NotWhitelistedStrat();

        infosByVault[vault_].strat = _strat;

        emit LogSetVaultStrat(vault_, strat_);
    }

    function fundVaultBalance(address vault_) external payable {
        // check if the vault_ is managed.
        if (!_vaults.contains(vault_)) revert OnlyManagedVault();

        if (msg.value == 0) revert NotNativeCoinSent();

        uint256 currentBalance = infosByVault[vault_].balance;

        infosByVault[vault_].balance = currentBalance + msg.value;

        emit LogFundBalance(vault_, currentBalance + msg.value);
    }

    function withdrawVaultBalance(
        address vault_,
        uint256 amount_,
        address receiver_
    ) external {
        bytes32 vaultType = IArrakisMetaVault(vault_).vaultType();

        if (vaultType == NFTTYPE) {
            address o = IOwnerOf(terms).ownerOf(vault_);
            if (msg.sender != o) revert OnlyVaultOwner(msg.sender, o);
        } else if (vaultType == ERC20TYPE) {
            if (msg.sender != owner()) revert OnlyOwner();
        } else revert VaultTypeNotSupported(vaultType);

        // check if the vault_ is managed.
        if (!_vaults.contains(vault_)) revert OnlyManagedVault();

        uint256 oldBalance = infosByVault[vault_].balance;

        if (oldBalance >= amount_) revert NoEnoughBalance();

        // #region effects.

        uint256 newBalance = oldBalance - amount_;

        infosByVault[vault_].balance = newBalance;

        Address.sendValue(payable(receiver_), amount_);

        // #endregion effects.

        emit LogWithdrawVaultBalance(vault_, amount_, receiver_, newBalance);
    }

    // #endregion initManagements.

    // #region view public functions.

    function whitelistedStrategies()
        external
        view
        returns (bytes32[] memory strats)
    {
        strats = _strats.values();
    }

    function whitelistedVaults()
        external
        view
        returns (address[] memory vaults)
    {
        return _vaults.values();
    }

    function whitelistedNftRebalancers()
        external
        view
        returns (address[] memory rebalancers)
    {
        return _nftRebalancers.values();
    }

    function whitelistedRebalancers()
        external
        view
        returns (address[] memory rebalancers)
    {
        return _rebalancers.values();
    }

    // #endregion view public functions.

    // #region internal functions.

    function _initManagement(SetupParams memory params_) internal {
        // #region checks.

        // check vault address is not address zero.
        if (address(params_.vault) == address(0)) revert AddressZero();

        // check is not already in management.
        if (_vaults.contains(params_.vault)) revert AlreadyInManagement();

        // check if standard manager is the vault manager.
        address manager = IArrakisMetaVault(params_.vault).manager();
        if (address(this) != manager)
            revert NotTheManager(address(this), manager);

        // check oracle is not address zero.
        if (address(params_.oracle) == address(0)) revert AddressZero();

        // check slippage is lower than 10%
        if (params_.maxSlippage > TEN_PERCENT) revert SlippageTooHigh();

        // check deviation is lower than 10%
        if (params_.maxDeviation > TEN_PERCENT) revert MaxDeviationTooHigh();

        // check we have a cooldown period.
        if (params_.coolDownPeriod == 0) revert CoolDownPeriodSetToZero();

        // check balance.
        if (msg.value != params_.balance)
            revert ValueDtBalanceInputed(msg.value, params_.balance);

        // check strategy is whitelisted.
        if (_strats.contains(params_.strat)) revert StratNotWhitelisted();

        // #endregion checks.

        // #region effects.

        _vaults.add(params_.vault);
        infosByVault[params_.vault] = VaultInfo({
            balance: params_.balance,
            lastRebalance: 0,
            datas: params_.datas,
            oracle: params_.oracle,
            maxSlippage: params_.maxSlippage,
            maxDeviation: params_.maxDeviation,
            coolDownPeriod: params_.coolDownPeriod,
            strat: params_.strat
        });

        // #endregion effects.

        // #region interactions.

        IArrakisLPModule(IArrakisMetaVault(params_.vault).module())
            .setManagerFeePIPS(defaultFeePIPS);

        // #endregion interactions.
    }

    // #endregion internal functions.
}
