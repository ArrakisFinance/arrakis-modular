// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.19;

import {
    ISafe, Operation
} from "../../../../src/interfaces/ISafe.sol";

import {IPALMTerms} from "../../../../src/interfaces/IPALMTerms.sol";
import {IWETH9} from "../../../../src/interfaces/IWETH9.sol";
import {IArrakisMetaVaultPrivate} from
    "../../../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisStandardManager} from
    "../../../../src/interfaces/IArrakisStandardManager.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StdCheats} from "forge-std/StdCheats.sol";

import {console} from "forge-std/console.sol";

contract SafeMock is ISafe, StdCheats {
    address public immutable token0;
    address public immutable token1;

    uint256 public amount0;
    uint256 public amount1;

    uint256 public revertStep;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    // #region mock functions.

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0 = amount0_;
        amount1 = amount1_;
    }

    function setRevertStep(
        uint256 revertStep_
    ) external {
        revertStep = revertStep_;
    }

    // #endregion mock functions.

    function getModulesPaginated(
        address start_,
        uint256 pageSize_
    ) external view returns (address[] memory array, address next) {
        return (new address[](0), address(0));
    }

    function disableModule(
        address prevModule_,
        address module_
    ) external override {}

    function execTransactionFromModule(
        address to_,
        uint256 value_,
        bytes calldata data_,
        Operation operation_
    ) external override returns (bool success) {
        bytes4 selector = bytes4(data_[:4]);

        if (selector == IPALMTerms.closeTerm.selector) {
            (
                address vault,
                address to,
                address newOwner,
                address newManager
            ) = abi.decode(
                data_[4:], (address, address, address, address)
            );

            deal(token0, to, amount0);
            deal(token1, to, amount1);

            if (revertStep == 1) {
                return false;
            }

            return true;
        }

        if (selector == IWETH9.withdraw.selector) {
            (uint256 amount) = abi.decode(data_[4:], (uint256));
            deal(address(this), amount);

            if (revertStep == 2) {
                return false;
            }

            return true;
        }

        if (
            selector
                == IArrakisMetaVaultPrivate.whitelistDepositors.selector
        ) {
            // Nothing to do here.

            if (revertStep == 3) {
                return false;
            }

            return true;
        }

        if (selector == IERC20.approve.selector) {
            // Nothing to do here.

            if (revertStep == 4) {
                return false;
            }

            return true;
        }

        if (selector == IArrakisMetaVaultPrivate.deposit.selector) {
            // Nothing to do here.

            if (revertStep == 5) {
                return false;
            }

            return true;
        }

        if (selector == IArrakisStandardManager.rebalance.selector) {
            // Nothing to do here.

            if (revertStep == 6) {
                return false;
            }

            return true;
        }

        if (
            selector
                == IArrakisStandardManager.updateVaultInfo.selector
        ) {
            // Nothing to do here.

            if (revertStep == 7) {
                return false;
            }

            return true;
        }

        if (selector == ISafe.disableModule.selector) {
            // Nothing to do here.

            if (revertStep == 8) {
                return false;
            }

            return true;
        }
    }
}
