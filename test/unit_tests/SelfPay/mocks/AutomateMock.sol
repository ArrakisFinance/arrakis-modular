// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {
    IAutomate,
    ITaskTreasuryUpgradable,
    ModuleData
} from "@gelato/automate/contracts/integrations/Types.sol";

contract AutomateMock is IAutomate {
    address payable public gelato;
    address public feeCollector;
    address public token;

    constructor(
        address feeCollector_,
        address token_,
        address gelato_
    ) {
        feeCollector = feeCollector_;
        token = token_;
        gelato = payable(gelato_);
    }

    function createTask(
        address,
        bytes calldata,
        ModuleData calldata,
        address
    ) external returns (bytes32) {

    }

    function cancelTask(bytes32) external {}

    function getFeeDetails()
        external
        view
        returns (uint256, address)
    {
        return (0, token);
    }

    function taskTreasury()
        external
        view
        returns (ITaskTreasuryUpgradable)
    {}
}
