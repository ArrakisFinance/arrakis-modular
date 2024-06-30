// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    IAutomate,
    ITaskTreasuryUpgradable,
    ModuleData
} from "@gelato/automate/contracts/integrations/Types.sol";

contract AutomateMock is IAutomate {
    address payable public gelato;
    address public feeCollector;
    address public token;

    uint256 public fee;

    constructor(
        address feeCollector_,
        address token_,
        address gelato_
    ) {
        feeCollector = feeCollector_;
        token = token_;
        gelato = payable(gelato_);
    }

    function setFee(uint256 fee_) external {
        fee = fee_;
    }

    function createTask(
        address,
        bytes calldata,
        ModuleData calldata,
        address
    ) external returns (bytes32) {}

    function cancelTask(bytes32) external {}

    function getFeeDetails()
        external
        view
        returns (uint256, address)
    {
        return (fee, token);
    }

    function taskTreasury()
        external
        view
        returns (ITaskTreasuryUpgradable)
    {}
}
