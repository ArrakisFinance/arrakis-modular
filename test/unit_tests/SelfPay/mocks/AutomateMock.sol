// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {
    IAutomate,
    ModuleData,
    Module,
    IGelato
} from "@gelato/automate/contracts/integrations/Types.sol";

contract GelatoMock is IGelato {
    address public feeCollector;

    constructor(address feeCollector_) {
        feeCollector = feeCollector_;
    }

    receive() external payable {}
}

contract AutomateMock is IAutomate {
    address payable public gelato;
    address public feeCollector;
    address public token;

    uint256 public fee;

    constructor(
        address feeCollector_,
        address token_
    ) {
        feeCollector = feeCollector_;
        token = token_;
        gelato = payable(address(new GelatoMock(feeCollector)));
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

    function taskModuleAddresses(Module) external view returns (address) {
        /// @dev gelato proxy module
        return 0x4C416F12B4c24559A38d5A93940d4b98e0aEF4D7;
    }
}
