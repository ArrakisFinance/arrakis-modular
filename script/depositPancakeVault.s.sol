// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IArrakisMetaVaultPrivate} from
    "../src/interfaces/IArrakisMetaVaultPrivate.sol";
import {IArrakisMetaVault} from
    "../src/interfaces/IArrakisMetaVault.sol";

import {IERC20Metadata} from
    "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

address constant vault = 0x931Ea526B8e2E0A76217B6b704B99cC977B32c5E;
uint256 constant amount0 = 0;
uint256 constant amount1 = 39 * (10 ** 18);

contract DepositPancakeVault is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log(msg.sender);

        // #region whitelist depositor.

        // IArrakisMetaVaultPrivate vaultContract =
        //     IArrakisMetaVaultPrivate(vault);

        // address[] memory depositors = new address[](1);
        // depositors[0] = msg.sender;

        // vaultContract.whitelistDepositors(depositors);

        // #endregion whitelist depositor.

        // #region approve tokens.

        address module = address(IArrakisMetaVault(vault).module());

        IERC20Metadata(IArrakisMetaVault(vault).token0()).approve(
            module,
            amount0
        );
        IERC20Metadata(IArrakisMetaVault(vault).token1()).approve(
            module,
            amount1
        );

        // #endregion approve tokens.

        // #region deposit.

        IArrakisMetaVaultPrivate(vault).deposit(
            amount0,
            amount1
        );

        // #endregion deposit.

        vm.stopBroadcast();
    }
}
