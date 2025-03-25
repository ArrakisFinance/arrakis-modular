// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {GnosisSafeProxy} from "./GnosisSafeProxy.sol";

interface IGnosisSafeProxyFactory {
    function createProxy(
        address singleton,
        bytes memory data
    ) external returns (GnosisSafeProxy proxy);
}
