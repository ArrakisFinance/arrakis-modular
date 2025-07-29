// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {IArrakisMetaVaultPrivate} from
    "../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";
import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

address constant vault = 0x958DBB1c8c41F737972A2064718C2cfe4AEbC0Fa;
address constant module = 0x622659982cC9e3e85aa09cE1a1d780EA8f1E110D;
address constant ownerDepositor =
    0xc1b9989ec4029e575006D9ac9e85A899F80BEbFc;
address constant trn = 0x1114982539A2Bfb84e8B9e4e320bbC04532a9e44;

contract TrnDepositSimulation is Script {
    function setUp() public {}

    function run() external {
        vm.startPrank(ownerDepositor);

        // #region approval.

        uint256 balance =
            IERC20Metadata(trn).balanceOf(ownerDepositor);
        console.log("balance", balance);

        IERC20Metadata(trn).approve(module, balance);

        // #endregion approval.
        // #region deposit.

        (uint256 amount0, uint256 amount1) =
            IArrakisMetaVault(vault).totalUnderlying();

        console.log("amount0", amount0);
        console.log("amount1", amount1);

        IArrakisMetaVaultPrivate(vault).deposit(balance, 0);

        uint256 amt0;

        (amt0, amount1) =
            IArrakisMetaVault(vault).totalUnderlying();

        console.log("amount0", amt0);
        console.log("amount1", amount1);

        console.log("Deposited TRN : ", amt0 - amount0);

        // #endregion deposit.

        vm.stopPrank();
    }
}
