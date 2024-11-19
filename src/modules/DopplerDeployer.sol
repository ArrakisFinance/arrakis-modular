// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {IDopplerDeployer} from "../interfaces/IDopplerDeployer.sol";
import {DopplerData} from "../structs/SDoppler.sol";

// #region openzeppelin.

import {Create2} from "@openzeppelin/contracts/utils/Create2.sol";

// #endregion openzeppelin.

import {Doppler} from "@doppler/src/Doppler.sol";

contract DopplerDeployer is IDopplerDeployer {
    function deployDoppler(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external override returns (address doppler) {

        // #region get the creation code for the Doppler contract.

        bytes memory creationCode = abi.encodePacked(
            type(Doppler).creationCode,
            abi.encode(
                poolManager_,
                dopplerData_.numTokensToSell,
                dopplerData_.minimumProceeds,
                dopplerData_.maximumProceeds,
                dopplerData_.startingTime,
                dopplerData_.endingTime,
                dopplerData_.startingTick,
                dopplerData_.endingTick,
                dopplerData_.epochLength,
                dopplerData_.gamma,
                dopplerData_.isToken0,
                dopplerData_.numPDSlugs,
                airlock_
            )
        );

        // #endregion get the creation code for the Doppler contract.

        return Create2.deploy(0, salt_, creationCode);
    }

    function computeAddress(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_,
        bytes32 salt_
    ) external view returns (address) {
        bytes memory creationCode = abi.encodePacked(
            type(Doppler).creationCode,
            abi.encode(
                poolManager_,
                dopplerData_.numTokensToSell,
                dopplerData_.minimumProceeds,
                dopplerData_.maximumProceeds,
                dopplerData_.startingTime,
                dopplerData_.endingTime,
                dopplerData_.startingTick,
                dopplerData_.endingTick,
                dopplerData_.epochLength,
                dopplerData_.gamma,
                dopplerData_.isToken0,
                dopplerData_.numPDSlugs,
                airlock_
            )
        );

        return Create2.computeAddress(salt_, keccak256(creationCode));
    }
}
