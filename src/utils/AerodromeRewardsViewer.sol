// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {ICLGauge} from "../interfaces/ICLGauge.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IArrakisLPModuleID} from
    "../interfaces/IArrakisLPModuleID.sol";
import {IAerodromeStandardModulePrivate} from
    "../interfaces/IAerodromeStandardModulePrivate.sol";
import {IAerodromeRewardsViewer} from
    "../interfaces/IAerodromeRewardsViewer.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract AerodromeRewardsViewer is IAerodromeRewardsViewer {
    address public immutable AERO;
    bytes32 public immutable id;

    constructor(address aero_, bytes32 id_) {
        if (aero_ == address(0)) {
            revert AddressZero();
        }

        AERO = aero_;
        id = id_;
    }

    function getClaimableRewards(
        address vault_
    ) external view returns (uint256 claimable) {
        // #region checks.

        if (vault_ == address(0)) {
            revert AddressZero();
        }

        // #endregion checks.

        address module = address(IArrakisMetaVault(vault_).module());

        if (IArrakisLPModuleID(module).id() != id) {
            revert NotAerodromeModule();
        }

        uint256[] memory tokenIds =
            IAerodromeStandardModulePrivate(module).tokenIds();

        address gauge =
            IAerodromeStandardModulePrivate(module).gauge();

        uint256 length = tokenIds.length;

        for (uint256 i = 0; i < length;) {
            uint256 tokenId = tokenIds[i];

            // Get the claimable rewards for each tokenId from the gauge
            claimable += ICLGauge(gauge).rewards(tokenId);
            claimable +=
                ICLGauge(gauge).earned(module, tokenId);

            unchecked {
                i += 1;
            }
        }

        claimable = (claimable + IERC20(AERO).balanceOf(module))
            - IAerodromeStandardModulePrivate(module).aeroManagerBalance();
    }
}
