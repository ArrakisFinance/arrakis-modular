// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IDistributor} from "../../../src/interfaces/IDistributor.sol";

contract CollectorMock {
    address public immutable distributor;

    constructor(
        address distributor_
    ) {
        distributor = distributor_;
    }

    function claim(
        address[] calldata users,
        address[] calldata tokens,
        uint256[] calldata amounts,
        bytes32[][] calldata proofs
    ) external {
        IDistributor(distributor).claim(
            users, tokens, amounts, proofs
        );
    }
}
