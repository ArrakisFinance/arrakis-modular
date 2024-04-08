// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISelfPay, SetupParams} from "./interfaces/ISelfPay.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {VaultInfo} from "./structs/SManager.sol";
import {IArrakisStandardManager} from
    "./interfaces/IArrakisStandardManager.sol";
import {IOracleWrapper} from "./interfaces/IOracleWrapper.sol";
import {IArrakisMetaVaultPrivate} from
    "./interfaces/IArrakisMetaVaultPrivate.sol";
import {NATIVE_COIN} from "./constants/CArrakis.sol";
import {IWETH9} from "./interfaces/IWETH9.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    SafeERC20,
    IERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from
    "@openzeppelin/contracts/token/IERC721Receiver.sol";
import {ReentrancyGuard} from
    "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract SelfPay is
    ISelfPay,
    Ownable,
    Initializable,
    IERC721Receiver
{
    using SafeERC20 for IERC20;
    using Address for address;

    // #region immutable public properties.

    address public immutable vault;
    address public immutable token0;
    address public immutable token1;
    address public immutable manager;
    address public immutable nft;

    address public immutable usdc;
    address public immutable weth;

    uint256 public immutable buffer;

    // eth/usdc chainlink oracle.
    IOracleWrapper public immutable oracle;
    bool public immutable oracleIsInversed;

    // #endregion immutable public properties.

    // #region public properties.

    address public w3f;
    address public router;
    address public receiver;

    // #endregion public properties.

    constructor(
        address owner_,
        address vault_,
        address manager_,
        address nft_,
        address w3f_,
        address router_,
        address receiver_,
        address usdc_,
        address oracle_,
        bool oracleIsInversed_,
        address weth_,
        uint256 buffer_
    ) {
        // #region checks.

        if (
            owner_ == address(0) || vault_ == address(0)
                || manager_ == address(0) || nft_ == address(0)
                || w3f_ == address(0) || router_ == address(0)
                || receiver_ == address(0) || oracle_ == address(0)
                || usdc_ == address(0) || weth_ == address(0)
        ) revert AddressZero();

        // #endregion checks.

        address _token0 = IArrakisMetaVault(vault_).token0();
        address _token1 = IArrakisMetaVault(vault_).token1();

        bool canBeSelfPay;
        if (
            _token0 == NATIVE_COIN || _token0 == usdc_
                || _token0 == weth_
        ) {
            canBeSelfPay = true;
        }
        if (
            _token1 == NATIVE_COIN || _token1 == usdc_
                || _token1 == weth_
        ) {
            canBeSelfPay = true;
        }

        if (!canBeSelfPay) {
            revert CantBeSelfPay();
        }

        _initializeOwner(owner_);
        vault = vault_;

        token0 = _token0;
        token1 = _token1;

        manager = manager_;
        nft = nft_;
        w3f = w3f_;
        router = router_;
        receiver = receiver_;
        oracle = oracle_;
        oracleIsInversed = oracleIsInversed_;
        usdc = usdc_;
        weth = weth_;

        buffer = buffer_;

        emit LogSetW3F(address(0), w3f_);
        emit LogSetRouter(address(0), router_);
        emit LogSetReceiver(address(0), receiver_);
    }

    function initialize() external initializer {
        address _vault = vault;
        address _nft = nft;
        address _manager = manager;

        // #region checks.

        /// @dev check that vault ownership
        /// is transferred or atleast we have approval.

        bool getApproved;
        address owner;
        uint256 tokenId = uint256(uint160(_vault));

        if (
            (owner = IERC721(_nft).ownerOf(uint256(uint160(_vault))))
                != address(this)
        ) {
            if (
                IERC721(_nft).getApproved(uint256(uint160(_vault)))
                    == address(this)
            ) {
                getApproved = true;
            } else {
                revert VaultNFTNotTransferedOrApproved();
            }
        }

        // #endregion checks.

        // #region effect.
        (
            uint256 lastRebalance,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            address executor,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
            uint24 managerFeePIPS
        ) = IArrakisStandardManager(_manager).vaultInfo(_vault);
        // #endregion effect.

        // #region interactions.

        // get the vault ownership.
        if (getApproved) {
            IERC721(_nft).safeTransferFrom(
                owner, address(this), uint256(uint160(_vault)), ""
            );
        }

        // add selfPay contract as depositor on the vault.
        address[] memory depositors = new address[](1);
        depositors[0] = address(this);

        IArrakisMetaVaultPrivate(_vault).whitelistDepositors(
            depositors
        );

        // call updateVault of manager.
        SetupParams memory params = SetupParams({
            vault: _vault,
            oracle: oracle,
            maxDeviation: maxDeviation,
            coolDownPeriod: cooldownPeriod,
            executor: address(this),
            stratAnnouncer: stratAnnouncer,
            maxSlippagePIPS: maxSlippagePIPS
        });

        IArrakisStandardManager(_manager).updateVaultInfo(params);

        // #endregion interactions.
    }

    // #region state modifying functions.

    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyOwner {
        address _vault = vault;
        address _token0 = token0;
        address _token1 = token1;

        // #region effects.

        address module = address(IArrakisMetaVault(_vault).module());

        // #endregion effects.

        // #region interactions.

        // get the tokens and approve.
        if (amount0_ > 0 && _token0 != NATIVE_COIN) {
            IERC20(_token0).safeTransferFrom(
                msg.sender, address(this), amount0_
            );
            IERC20(_token0).safeApprove(module, amount0_);
        }

        if (amount1_ > 0 && _token1 != NATIVE_COIN) {
            IERC20(_token1).safeTransferFrom(
                msg.sender, address(this), amount1_
            );
            IERC20(_token1).safeApprove(module, amount1_);
        }

        // call metaVault deposit.

        IArrakisMetaVaultPrivate(_vault).deposit{value: msg.value}(
            amount0_, amount1_
        );

        // #endregion interactions.

        emit LogOwnerDeposit(amount0_, amount1_);
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external onlyOwner {
        (uint256 amount0, uint256 amount1) = IArrakisMetaVaultPrivate(
            vault
        ).withdraw(proportion_, receiver_);

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

    function setW3F(address w3f_) external onlyOwner {
        address _w3f = w3f;
        if (w3f_ == address(0)) revert AddressZero();
        if (w3f_ == _w3f) revert SameW3F();

        w3f = w3f_;

        emit LogSetW3F(_w3f, w3f_);
    }

    function setRouter(address router_) external onlyOwner {
        address _router = router;
        if (router_ == address(0)) revert AddressZero();
        if (router_ == _router) revert SameRouter();

        router = router_;

        emit LogSetW3F(_router, router_);
    }

    function setReceiver(address receiver_) external onlyOwner {
        address _receiver = receiver;
        if (receiver_ == address(0)) revert AddressZero();
        if (receiver_ == _receiver) revert SameReceiver();

        receiver = receiver_;

        emit LogSetW3F(_receiver, receiver_);
    }

    function callRouter(
        bytes calldata payload_,
        uint256 amount0_,
        uint256 amount1_
    ) external payable onlyOwner nonReentrant {
        address _token0 = token0;
        address _token1 = token1;
        address _router = router;

        if (payload_ == "") revert EmptyCallData();

        if (amount0_ > 0 && _token0 != NATIVE_COIN) {
            if (_token0 != NATIVE_COIN) {
                IERC20(_token0).safeTransferFrom(
                    msg.sender, address(this), amount0_
                );
                IERC20(_token0).safeApprove(_router, amount0);
            }
        }

        if (amount1_ > 0 && _token1 != NATIVE_COIN) {
            IERC20(_token1).safeTransferFrom(
                msg.sender, address(this), amount0_
            );
            IERC20(_token1).safeApprove(_router, amount0);
        }

        (bool success,) = _router.call{value: msg.value}(payload_);

        if (!success) revert CallFailed();

        emit LogOwnerCallRouter(payload_, amount0_, amount1_);
    }

    function callNFT(bytes calldata payload_)
        external
        onlyOwner
        nonReentrant
    {
        if (payload_ == "") revert EmptyCallData();

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
        uint256 gas = gasleft();
        address _vault = vault;
        if (msg.sender != w3f) revert CallerNotW3F();

        IArrakisStandardManager(manager).rebalance(vault, payloads_);

        uint256 gasCost = gas - gasleft() + buffer;

        address module = address(IArrakisMetaVault(_vault).module());

        if (token0 == NATIVE_COIN) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            if (gasCost > amount0) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount0 = amount0 - gasCost;

            w3f.sendValue(gasCost);

            IERC20(token1).safeIncreaseAllowance(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit{value: amount0}(
                amount0, amount1
            );

            return;
        }
        if (token0 == weth) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(_vault).withdraw(
                1e18, address(this)
            );

            if (gasCost > amount0) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount0 = amount0 - gasCost;

            IWETH9(weth).withdraw(gasCost);

            w3f.sendValue(gasCost);

            IERC20(token0).safeIncreaseAllowance(module, amount0);
            IERC20(token1).safeIncreaseAllowance(module, amount1);

            IArrakisMetaVaultPrivate(_vault).deposit(amount0, amount1);

            return;
        }

        if (token1 == NATIVE_COIN) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            if (gasCost > amount1) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount1 = amount1 - gasCost;

            w3f.sendValue(gasCost);

            IERC20(token0).safeIncreaseAllowance(module, amount0);

            IArrakisMetaVaultPrivate(vault).deposit{value: amount1}(
                amount0, amount1
            );

            return;
        }
        if (token1 == weth) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            if (gasCost > amount1) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount1 = amount1 - gasCost;

            IWETH9(weth).withdraw(gasCost);

            w3f.sendValue(gasCost);

            IArrakisMetaVaultPrivate(vault).deposit(amount0, amount1);

            return;
        }

        if (token0 == usdc) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            uint256 amount0InEth = oracleIsInversed
                ? FullMath.mulDiv(amount0 * 1e18, oracle.getPrice1(), 1e6)
                : FullMath.mulDiv(amount0 * 1e18, oracle.getPrice0(), 1e6);

            if (gasCost > amount0InEth) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount0InEth = amount0InEth - gasCost;

            uint256 amountToSend = oracleIsInversed
                ? FullMath.mulDiv(
                    amount0InEth * 1e6, oracle.getPrice0(), 1e18
                )
                : FullMath.mulDiv(
                    amount0InEth * 1e6, oracle.getPrice1(), 1e18
                );

            IERC20(token0).safeTransfer(w3f, amountToSend);
            IERC20(token0).safeIncreaseAllowance(
                module, amount0 - amountToSend
            );
            IERC20(token1).safeIncreaseAllowance(module, amount1);

            IArrakisMetaVaultPrivate(vault).deposit(
                amount0 - amountToSend, amount1
            );

            return;
        }

        if (token1 == usdc) {
            (uint256 amount0, uint256 amount1) =
            IArrakisMetaVaultPrivate(vault).withdraw(
                1e18, address(this)
            );

            uint256 amount1InEth = oracleIsInversed
                ? FullMath.mulDiv(amount1 * 1e18, oracle.getPrice1(), 1e6)
                : FullMath.mulDiv(amount1 * 1e18, oracle.getPrice0(), 1e6);

            if (gasCost > amount1InEth) {
                revert NotEnoughTokenToPayForRebalance();
            }

            amount1InEth = amount1InEth - gasCost;

            uint256 amountToSend = oracleIsInversed
                ? FullMath.mulDiv(
                    amount1InEth * 1e6, oracle.getPrice0(), 1e18
                )
                : FullMath.mulDiv(
                    amount1InEth * 1e6, oracle.getPrice1(), 1e18
                );

            IERC20(token1).safeTransfer(w3f, amountToSend);
            IERC20(token1).safeIncreaseAllowance(
                module, amount1 - amountToSend
            );
            IERC20(token0).safeIncreaseAllowance(module, amount0);

            IArrakisMetaVaultPrivate(vault).deposit(
                amount0, amount1 - amountToSend
            );

            return;
        }
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
