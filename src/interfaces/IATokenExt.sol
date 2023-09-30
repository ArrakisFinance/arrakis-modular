// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IAToken} from "aave-v3-core/contracts/interfaces/IAToken.sol";
import {IPool} from "aave-v3-core/contracts/interfaces/IPool.sol";
interface IATokenExt is IAToken {
    function POOL() external view returns (IPool);
}