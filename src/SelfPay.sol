// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ISelfPay, SetupParams} from "./interfaces/ISelfPay.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {VaultInfo} from "./structs/SManager.sol";
import {IArrakisStandardManager} from
    "./interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVaultPrivate} from
    "./interfaces/IArrakisMetaVaultPrivate.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";
import {IOracleWrapper} from "./interfaces/IOracleWrapper.sol";

// #region gelato.

import {AutomateReady} from
    "@gelato/automate/contracts/integrations/AutomateReady.sol";

// #endregion gelato.

// #region solady.

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

// #endregion solady.

// #region openzeppelin.

import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// #endregion openzeppelin.

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract SelfPay is
    AutomateReady,
    Ownable,
    Initializable,
    ReentrancyGuard,
    ISelfPay,
    IERC721Receiver
{
    using SafeERC20 for IERC20;
    using Address for address payable;

    // #region immutable public properties.

    address public immutable vault;
    address public immutable token0;
    address public immutable token1;
    address public immutable manager;
    address public immutable nft;

    address public immutable weth;

    // #endregion immutable public properties.

    // #region public properties.

    address public executor;

    // #endregion public properties.

    constructor(
        address owner_,
        address vault_,
        address manager_,
        address nft_,
        address executor_,
        address automate_,
        address taskCreator_,
        address weth_
    ) AutomateReady(automate_, taskCreator_) {
        // #region checks.

        if (
            owner_ == address(0) || vault_ == address(0)
                || manager_ == address(0) || nft_ == address(0)
                || executor_ == address(0) || automate_ == address(0)
                || taskCreator_ == address(0) || weth_ == address(0)
        ) revert AddressZero();

        // #endregion checks.

        address _token0 = IArrakisMetaVault(vault_).token0();
        address _token1 = IArrakisMetaVault(vault_).token1();

        bool canBeSelfPay;

        (, address feeToken) = _getFeeDetails();

        if (_token0 == feeToken || _token1 == feeToken) {
            canBeSelfPay = true;
        }

        if (feeToken == ETH && (_token0 == weth_ || _token1 == weth_))
        {
            canBeSelfPay = true;
        }

        if (!canBeSelfPay) revert CantBeSelfPay();

        _initializeOwner(owner_);
        vault = vault_;

        token0 = _token0;
        token1 = _token1;

        manager = manager_;
        nft = nft_;
        executor = executor_;

        weth = weth_;
    }

    function initialize() external initializer {
        address _vault = vault;
        address _nft = nft;
        address _manager = manager;

        // #region checks.

        /// @dev check that vault ownership
        /// is transferred or atleast we have approval.

        bool getApproved;
        address tokenOwner;
        uint256 tokenId = uint256(uint160(_vault));

        if (
            (tokenOwner = IERC721(_nft).ownerOf(tokenId))
                != address(this)
        ) {
            if (IERC721(_nft).getApproved(tokenId) == address(this)) {
                getApproved = true;
            } else {
                revert VaultNFTNotTransferedOrApproved();
            }
        }

        // #endregion checks.

        // #region effect.
        (
            ,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            ,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
        ) = IArrakisStandardManager(_manager).vaultInfo(_vault);
        // #endregion effect.

        // #region interactions.

        // get the vault ownership.
        if (getApproved) {
            IERC721(_nft).safeTransferFrom(
                tokenOwner, address(this), tokenId, ""
            );
        }

        // call updateVault of manager.
        SetupParams memory params = SetupParams({
            vault: _vault,
            oracle: oracle,
            maxDeviation: maxDeviation,
            cooldownPeriod: cooldownPeriod,
            executor: address(this),
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        // #region whitelist as depositor.

        address[] memory depositors = new address[](1);
        depositors[0] = address(this);

        IArrakisMetaVaultPrivate(vault).whitelistDepositors(
            depositors
        );

        // #endregion whitelist as depositor.

        IArrakisStandardManager(_manager).updateVaultInfo(params);

        // #endregion interactions.
    }

    // #region state modifying functions.

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external onlyOwner returns (uint256 amount0, uint256 amount1) {
        (amount0, amount1) = IArrakisMetaVaultPrivate(vault).withdraw(
            proportion_, receiver_
        );

        emit LogOwnerWithdraw(proportion_, amount0, amount1);
    }

    function whitelistDepositors(address[] calldata depositors_)
        external
        onlyOwner
    {
        IArrakisMetaVaultPrivate(vault).whitelistDepositors(
            depositors_
        );

        emit LogOwnerWhitelistDepositors(depositors_);
    }

    function blacklistDepositors(address[] calldata depositors_)
        external
        onlyOwner
    {
        IArrakisMetaVaultPrivate(vault).blacklistDepositors(
            depositors_
        );

        emit LogOwnerBlacklistDepositors(depositors_);
    }

    function whitelistModules(
        address[] calldata beacons_,
        bytes[] calldata payloads_
    ) external onlyOwner {
        IArrakisMetaVault(vault).whitelistModules(beacons_, payloads_);

        emit LogOwnerWhitelistModules(beacons_, payloads_);
    }

    function blacklistModules(address[] calldata modules_)
        external
        onlyOwner
    {
        IArrakisMetaVault(vault).blacklistModules(modules_);

        emit LogOwnerBlacklistModules(modules_);
    }

    function setExecutor(address executor_) external onlyOwner {
        address _executor = executor;
        if (executor_ == address(0)) revert AddressZero();
        if (executor_ == _executor) revert SameExecutor();

        executor = executor_;

        emit LogSetExecutor(_executor, executor_);
    }

    function callNFT(bytes calldata payload_)
        external
        onlyOwner
        nonReentrant
    {
        if (payload_.length == 0) revert EmptyCallData();

        (bool success,) = nft.call(payload_);

        if (!success) revert CallFailed();

        emit LogOwnerCallNFT(payload_);
    }

    function updateVaultInfo(SetupParams calldata params_)
        external
        onlyOwner
    {
        IArrakisStandardManager(manager).updateVaultInfo(params_);

        emit LogOwnerUpdateVaultInfo(params_);
    }

    function rebalance(bytes[] calldata payloads_)
        external
        nonReentrant
    {
        if (msg.sender != executor) revert OnlyExecutor();

        address module = address(IArrakisMetaVault(vault).module());

        (uint256 fee, address feeToken) = _getFeeDetails();

        if (feeToken == token0) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            _transfer(fee, feeToken);

            amount0 = amount0 - fee;

            IERC20(token1).safeIncreaseAllowance(module, amount1);

            if (feeToken == ETH) {
                IArrakisMetaVaultPrivate(vault).deposit{
                    value: amount0
                }(amount0, amount1);
            } else {
                IERC20(token0).safeIncreaseAllowance(module, amount0);

                IArrakisMetaVaultPrivate(vault).deposit(
                    amount0, amount1
                );
            }

            return;
        }

        if (feeToken == token1) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            _transfer(fee, feeToken);

            amount1 = amount1 - fee;

            IERC20(token0).safeIncreaseAllowance(module, amount0);

            if (feeToken == ETH) {
                IArrakisMetaVaultPrivate(vault).deposit{
                    value: amount1
                }(amount0, amount1);
            } else {
                IERC20(token1).safeIncreaseAllowance(module, amount1);

                IArrakisMetaVaultPrivate(vault).deposit(
                    amount0, amount1
                );
            }

            return;
        }

        if (feeToken == ETH) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            if (token0 == weth) {
                amount0 = amount0 - fee;
            } else {
                amount1 = amount1 - fee;
            }

            IWETH9(weth).withdraw(fee);

            _transfer(fee, feeToken);

            IERC20(token0).safeIncreaseAllowance(module, amount0);
            IERC20(token1).safeIncreaseAllowance(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            return;
        }

        IArrakisStandardManager(manager).rebalance(vault, payloads_);
    }

    receive() external payable {}

    // #endregion state modifying functions.

    // #region IERC721Receiver functions.

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // #endregion IERC721Receiver functions.
}
