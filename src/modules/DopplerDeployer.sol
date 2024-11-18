// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.26;

import {IPoolManager} from
    "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

import {IDopplerDeployer} from "../interfaces/IDopplerDeployer.sol";
import {DopplerData} from "../structs/SDoppler.sol";

// import {Doppler} from "@doppler/src/Doppler.sol";

contract DopplerDeployer is IDopplerDeployer {
    function deployDoppler(
        IPoolManager poolManager_,
        DopplerData calldata dopplerData_,
        address airlock_
    ) external override returns (address doppler) {
        // return address(
        //     new Doppler(
        //         poolManager_,
        //         dopplerData_.numTokensToSell,
        //         dopplerData_.minimumProceeds,
        //         dopplerData_.maximumProceeds,
        //         dopplerData_.startingTime,
        //         dopplerData_.endingTime,
        //         dopplerData_.startingTick,
        //         dopplerData_.endingTick,
        //         dopplerData_.epochLength,
        //         dopplerData_.gamma,
        //         dopplerData_.isToken0,
        //         dopplerData_.numPDSlugs,
        //         airlock_
        //     )
        // );
    }
}
