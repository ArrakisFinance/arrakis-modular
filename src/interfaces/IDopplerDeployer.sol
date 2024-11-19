// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {DopplerData} from "../structs/SDoppler.sol";

interface IDopplerDeployer {
    function deployDoppler(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external returns (address);

    function computeAddress(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external view returns (address);
}
