// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IUniV4StandardModule} from
    "../../../../src/interfaces/IUniV4StandardModule.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract Module {

    IUniV4StandardModule.Range[] internal _ranges;
    PoolKey public poolKey;
    bool public isInversed;

    function setRanges(
        IUniV4StandardModule.Range[] memory ranges
    ) external {
        for (uint256 i = 0; i < ranges.length; i++) {
            _ranges.push(ranges[i]);
        }
    }

    function getRanges()
        external
        view
        returns (IUniV4StandardModule.Range[] memory ranges)
    {
        return _ranges;
    }

    function setPoolKey(
        PoolKey memory poolKey_
    ) external {
        poolKey = poolKey_;
    }

    function setIsInversed(bool isInversed_) external {
        isInversed = isInversed_;
    }
}
