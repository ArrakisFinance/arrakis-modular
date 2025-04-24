// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IDistributor} from "../../../src/interfaces/IDistributor.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CollectorMock {
    using SafeERC20 for IERC20;

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

    function transferFrom(
        address token,
        address from,
        uint256 amount
    ) external {
        IERC20(token).safeTransferFrom(
            from, address(this), amount
        );
    }
}
