// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ISelfPay} from "./interfaces/ISelfPay.sol";
import {IArrakisMetaVault} from "./interfaces/IArrakisMetaVault.sol";
import {VaultInfo} from "./structs/SManager.sol";
import {IArrakisStandardManager} from
    "./interfaces/IArrakisStandardManager.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

import {Initializable} from
    "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {IERC721} from
    "@openzeppelin/contracts/token/ERC721/IERC721.sol";

contract SelfPay is ISelfPay, Ownable, Initializable {
    // #region immutable public properties.

    address public immutable vault;
    address public immutable token0;
    address public immutable token1;
    address public immutable manager;
    address public immutable nft;

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
        address receiver_
    ) {
        // #region checks.

        if (
            owner_ == address(0) || vault_ == address(0)
                || manager_ == address(0) || nft_ == address(0)
                || w3f_ == address(0) || router_ == address(0)
                || receiver_ == address(0)
        ) revert AddressZero();

        // #endregion checks.

        _initializeOwner(owner_);
        vault = vault_;

        token0 = IArrakisMetaVault(vault_).token0();
        token1 = IArrakisMetaVault(vault_).token1();

        manager = manager_;
        nft = nft_;
        w3f = w3f_;
        router = router_;
        receiver = receiver_;

        emit LogSetW3F(address(0), w3f_);
        emit LogSetRouter(address(0), router_);
        emit LogSetReceiver(address(0), receiver_);
    }

    function initialize() external onlyOwner initializer {
        address _vault = vault;
        address _nft = nft;

        // #region checks.

        /// @dev check that vault ownership
        /// is transferred or atleast we have approval.

        if (
            !IERC721(_nft).ownerOf(uint256(uint160(_vault)))
                || IERC721(_nft).getApproved(uint256(uint160(_vault)))
        ) revert VaultNFTNotTransferedOrApproved();

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
        ) = IArrakisStandardManager(manager).vaultInfo(vault);

        // #endregion effect.
    }
}
