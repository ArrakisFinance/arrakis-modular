// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {IPausable} from "../src/interfaces/IPausable.sol";
import {ArrakisRoles} from "./deployment/constants/ArrakisRoles.sol";

contract PauseModules is Script {

    function run() public {
        address pauser = ArrakisRoles.getAdmin();
        address owner = ArrakisRoles.getOwner();

        address[2] memory modules = [
            address(0),
            address(0)
        ];

        console.log("Pauser safe address : ", pauser);

        /// @dev creation of json to create a batch of transaction.

        string memory js = "{\"version\":\"1.0\",\"chainId\":\"";

        js = string.concat(js,vm.toString(block.chainid));

        js = string.concat(js, '","meta":{"name":"Transactions Batch","description":"","txBuilderVersion":"1.18.0","createdFromSafeAddress":"');
        js = string.concat(js, vm.toString(owner));
        js = string.concat(js, '","createdFromOwnerAddress":""},"transactions":[');

        if (modules.length > 0) {
            js = string.concat(js, '{"to":"', vm.toString(modules[0]), '","value":"0","data":null,"contractMethod":{"name":"pause","payable":false}}');
        }

        for(uint256 i = 1; i<modules.length; i++) {
            js = string.concat(js, ',{"to":"', vm.toString(modules[i]), '","value":"0","data":null,"contractMethod":{"name":"pause","payable":false}}');
        }

        js = string.concat(js, ']}');

        console.logString(js);
    }
}
