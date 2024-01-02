// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IManager} from "./interfaces/IManager.sol";
import {IArrakisLPModule} from "./interfaces/IArrakisLPModule.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {Ownable} from "@solady/contracts/auth/Ownable.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract Manager is IManager, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // #region public properties.

    mapping(address => address) public receiversByToken;
    address public defaultReceiver;

    // #endregion public properties.

    // #region internal properties.

    EnumerableSet.AddressSet internal _whitelistedVaults;
    EnumerableSet.AddressSet internal _whitelistedRebalancers;

    // #endregion internal properties.

    constructor(address owner_, address defaultReceiver_) {
        if (owner_ == address(0) || defaultReceiver_ == address(0))
            revert AddressZero();
        _initializeOwner(owner_);
        defaultReceiver = defaultReceiver_;

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
        if (!_whitelistedVaults.contains(vault_))
            revert NotWhitelistedVault(vault_);

        if (receiver_ == address(0)) revert AddressZero();

        address token;
        if (isSetReceiverToken0_)
            token = address(IArrakisMetaVault(vault_).token0());
        else token = address(IArrakisMetaVault(vault_).token1());

        receiversByToken[token] = receiver_;

        emit LogSetReceiverByToken(token, receiver_);
    }

    // #endregion owner settable functions.

    function withdrawManagerBalance(
        address vault_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        if (!_whitelistedVaults.contains(vault_))
            revert NotWhitelistedVault(vault_);

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

    function whitelistVaults(address[] calldata vaults_) external onlyOwner {
        uint256 _length = vaults_.length;
        if (_length == 0) revert EmptyVaultsArray();

        for (uint256 i; i < _length; i++) {
            address _vault = vaults_[i];

            if (_vault == address(0)) revert AddressZero();

            if (_whitelistedVaults.contains(_vault))
                revert AlreadyWhitelistedVault(_vault);

            _whitelistedVaults.add(_vault);
        }

        emit LogWhitelistVaults(vaults_);
    }

    function whitelistRebalancers(
        address[] calldata rebalancers_
    ) external onlyOwner {
        uint256 _length = rebalancers_.length;
        if (_length == 0) revert EmptyRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _rebalancer = rebalancers_[i];

            if (_rebalancer == address(0)) revert AddressZero();

            if (_whitelistedRebalancers.contains(_rebalancer))
                revert AlreadyWhitelistedRebalancer(_rebalancer);

            _whitelistedRebalancers.add(_rebalancer);
        }

        emit LogWhitelistRebalancers(rebalancers_);
    }

    function blacklistVaults(address[] calldata vaults_) external onlyOwner {
        uint256 _length = vaults_.length;
        if (_length == 0) revert EmptyVaultsArray();

        for (uint256 i; i < _length; i++) {
            address _vault = vaults_[i];

            if (_vault == address(0)) revert AddressZero();

            if (!_whitelistedVaults.contains(_vault))
                revert NotWhitelistedVault(_vault);

            _whitelistedVaults.remove(_vault);
        }

        emit LogBlacklistVaults(vaults_);
    }

    function blacklistRebalancers(
        address[] calldata rebalancers_
    ) external onlyOwner {
        uint256 _length = rebalancers_.length;
        if (_length == 0) revert EmptyRebalancersArray();

        for (uint256 i; i < _length; i++) {
            address _rebalancer = rebalancers_[i];

            if (_rebalancer == address(0)) revert AddressZero();

            if (!_whitelistedRebalancers.contains(_rebalancer))
                revert NotWhitelistedRebalancer(_rebalancer);

            _whitelistedRebalancers.remove(_rebalancer);
        }

        emit LogBlacklistRebalancers(rebalancers_);
    }

    function rebalance(address vault_, bytes[] calldata payloads_) external {
        if (!_whitelistedRebalancers.contains(msg.sender))
            revert OnlyRebalancers(msg.sender);

        if (!_whitelistedVaults.contains(vault_))
            revert NotWhitelistedVault(vault_);

        uint256 _length = payloads_.length;

        for (uint256 i; i < _length; i++) {
            (bool success, ) = address(IArrakisMetaVault(vault_).module()).call(
                payloads_[i]
            );

            if (!success) revert CallFailed(payloads_[i]);
        }

        emit LogRebalance(vault_, payloads_);
    }

    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external onlyOwner {
        if (!_whitelistedVaults.contains(vault_))
            revert NotWhitelistedVault(vault_);

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
            if (!_whitelistedVaults.contains(_vault))
                revert NotWhitelistedVault(_vault);

            IArrakisMetaVault(_vault).module().setManagerFeePIPS(feesPIPS_[i]);
        }

        emit LogSetManagerFeePIPS(vaults_, feesPIPS_);
    }

    // #region view functions.

    function whitelistedVaults()
        external
        view
        returns (address[] memory vaults)
    {
        return _whitelistedVaults.values();
    }

    function whitelistedRebalancers()
        external
        view
        returns (address[] memory rebalancers)
    {
        return _whitelistedRebalancers.values();
    }

    // #endregion view functions.
}
