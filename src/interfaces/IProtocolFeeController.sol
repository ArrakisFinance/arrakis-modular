//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PoolKey} from "@pancakeswap/v4-core/src/types/PoolKey.sol";

interface IProtocolFeeController {
    /// @notice Get the protocol fee for a pool given the conditions of this contract
    /// @param poolKey The pool key to identify the pool. The controller may want to use attributes on the pool
    ///   to determine the protocol fee, hence the entire key is needed.
    /// @return protocolFee The pool's protocol fee, expressed in hundredths of a bip. The upper 12 bits are for 1->0
    /// and the lower 12 are for 0->1. The maximum is 4000 - meaning the maximum protocol fee is 0.4%.
    /// the protocolFee is taken from the input first, then the lpFee is taken from the remaining input
    function protocolFeeForPool(PoolKey memory poolKey) external view returns (uint24 protocolFee);


    /// @notice Get the LP fee based on protocolFeeSplitRatio and total fee. This is useful for FE to calculate the LP fee
    /// based on user's input when initializing a static fee pool
    /// warning: if protocolFee is over 0.4% based on the totalFee, then it will be capped at 0.4% which means
    /// lpFee in this case will charge more lpFee than expected i.e more than "1 - protocolFeeSplitRatio"
    /// @param totalFee The total fee (including lpFee and protocolFee) for the pool, expressed in hundredths of a bip
    /// @return lpFee The LP fee that can be passed in as poolKey.fee, expressed in hundredths of a bip
    function getLPFeeFromTotalFee(uint24 totalFee) external view returns (uint24);
}
