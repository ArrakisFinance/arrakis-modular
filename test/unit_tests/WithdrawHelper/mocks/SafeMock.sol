// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    ISafe, Operation
} from "../../../../src/interfaces/ISafe.sol";

import {IPALMTerms} from "../../../../src/interfaces/IPalmTerms.sol";
import {IWETH9} from "../../../../src/interfaces/IWETH9.sol";
import {IArrakisMetaVaultPrivate} from
    "../../../../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisStandardManager} from
    "../../../../src/interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVaultFactory} from
    "../../../../src/interfaces/IArrakisMetaVaultFactory.sol";
import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";
import {NATIVE_COIN} from "../../../../src/constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {StdCheats} from "forge-std/StdCheats.sol";

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
        if (data_.length == 0) {
            if (revertStep == 2) {
                return false;
            }

            if (revertStep == 8) {
                return false;
            }

            return true;
        }

        bytes4 selector = bytes4(data_[:4]);

        if (selector == IArrakisMetaVaultPrivate.withdraw.selector) {
            if (amount0 > 0) {
                if (NATIVE_COIN == token0) {
                    deal(address(this), amount0);
                } else {
                    deal(token0, address(this), amount0);
                }
            }

            if (amount1 > 0) {
                if (NATIVE_COIN == token1) {
                    deal(address(this), amount1);
                } else {
                    deal(token1, address(this), amount1);
                }
            }

            if (revertStep == 1) {
                return false;
            }

            return true;
        }

        if (
            selector
                == IArrakisMetaVaultPrivate.whitelistDepositors.selector
        ) {
            // Nothing to do here.

            if (revertStep == 10) {
                return false;
            }

            return true;
        }

        if (selector == IArrakisMetaVaultPrivate.deposit.selector) {
            // Nothing to do here.

            if (revertStep == 19) {
                return false;
            }

            return true;
        }
    }

    function execTransactionFromModuleReturnData(
        address to,
        uint256 value,
        bytes calldata data,
        Operation operation
    ) external returns (bool success, bytes memory returnData) {
        bytes4 selector = bytes4(data[:4]);

        if (selector == IERC20.transfer.selector) {
            // Nothing to do here.

            if (revertStep == 2) {
                return (false, abi.encode(true));
            }

            if (revertStep == 3) {
                return (true, abi.encode(false));
            }

            if (revertStep == 4) {
                return (false, abi.encode(false));
            }

            if (revertStep == 5) {
                return (false, "");
            }

            if (revertStep == 6) {
                return (false, abi.encode(true));
            }

            if (revertStep == 7) {
                return (true, abi.encode(false));
            }

            if (revertStep == 8) {
                return (false, abi.encode(false));
            }

            if (revertStep == 9) {
                return (false, "");
            }

            return (true, abi.encode(true));
        }

        if (selector == IERC20.approve.selector) {
            // Nothing to do here.

            if (revertStep == 11) {
                return (false, abi.encode(true));
            }

            if (revertStep == 12) {
                return (true, abi.encode(false));
            }

            if (revertStep == 13) {
                return (false, abi.encode(false));
            }

            if (revertStep == 14) {
                return (false, "");
            }

            if (revertStep == 15) {
                return (false, abi.encode(true));
            }

            if (revertStep == 16) {
                return (true, abi.encode(false));
            }

            if (revertStep == 17) {
                return (false, abi.encode(false));
            }

            if (revertStep == 18) {
                return (false, "");
            }

            return (true, abi.encode(true));
        }
    }
}
