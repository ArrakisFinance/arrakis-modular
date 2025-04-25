// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IArrakisV2} from "../src/interfaces/IArrakisV2.sol";

interface IPALMTerms {
    struct SetupPayload {
        // Initialized Payload properties
        uint24[] feeTiers;
        IERC20 token0;
        IERC20 token1;
        address owner;
        uint256 amount0;
        uint256 amount1;
        bytes datas;
        string strat;
        bool isBeacon;
        address delegate;
        address[] routers;
    }

    function openTerm(
        SetupPayload calldata setup_
    ) external payable returns (address vault);
}

contract CreatePalmVault is Script {

    address public constant token0 = 0x4200000000000000000000000000000000000006;
    address public constant token1 = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    uint24 public constant feeTier = 100;
    address public constant owner = 0xeA50ffF6714C9910FdE2e3711C52406803045495;
    uint256 public constant amount0 = 1 ether/10000;
    uint256 public constant amount1 = 1000000/10;
    bytes public constant datas = "0x";
    bool public constant isBeacon = true;
    address public constant delegate = 0x81a1e7F34b9bABf172087cF5df8A4DF6500e9d4d;
    address[] public routers = [
        0x2626664c2603336E57B271c5C0b26F421741e481,
        0x6fF5693b99212Da76ad316178A184AB56D299b43
    ];
    string public constant strat = "BOOTSTRAPPING";

    address public constant palmTerms = 0xB041f628e961598af9874BCf30CC865f67fad3EE;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        console.log("Creating Palm Vault...");

        console.log("Sender address:");
        console.log(msg.sender);

        IERC20(token0).approve(palmTerms, amount0);
        IERC20(token1).approve(palmTerms, amount1);

        IPALMTerms.SetupPayload memory setup = IPALMTerms.SetupPayload({
            feeTiers: new uint24[](1),
            token0: IERC20(token0),
            token1: IERC20(token1),
            owner: owner,
            amount0: amount0,
            amount1: amount1,
            datas: datas,
            strat: strat,
            isBeacon: isBeacon,
            delegate: delegate,
            routers: routers
        });

        setup.feeTiers[0] = feeTier;

        address vault = IPALMTerms(palmTerms).openTerm(setup);
        console.log("Vault address:");
        console.log(vault);

        vm.stopBroadcast();
    }
}
