// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PUBLIC_TYPE} from "../../../../src/constants/CArrakis.sol";

contract ArrakisPublicVaultMock {
    address public manager;

    function vaultType() external pure returns (bytes32) {
        return PUBLIC_TYPE;
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    function setModule(address module) external {}

    function withdrawManagerFee()
        external
        returns (uint256 amount0, uint256 amount1)
    {
        
    }
}
