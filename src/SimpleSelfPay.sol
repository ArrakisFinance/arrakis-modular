// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ISimpleSelfPay} from "./interfaces/ISimpleSelfPay.sol";
import {IArrakisStandardManager} from
    "./interfaces/IArrakisStandardManager.sol";

// #region gelato.

import {AutomateReady} from
    "@gelato/automate/contracts/integrations/AutomateReady.sol";

// #endregion gelato.

// #region openzeppelin.

import {ReentrancyGuard} from
    "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

// #endregion openzeppelin.

contract SimpleSelfPay is
    ReentrancyGuard,
    AutomateReady,
    ISimpleSelfPay
{
    using Address for address payable;

    // #region immutable variable.

    address public immutable executor;
    address public immutable manager;
    address public immutable vault;
    address payable public immutable receiver;

    // #endregion immutable variable.

    constructor(
        address automate_,
        address taskCreator_,
        address executor_,
        address manager_,
        address vault_,
        address receiver_
    ) AutomateReady(automate_, taskCreator_) {
        if (
            vault_ == address(0) || manager_ == address(0)
                || executor_ == address(0) || taskCreator_ == address(0)
                || receiver_ == address(0)
        ) revert AddressZero();

        (, address feeToken) = _getFeeDetails();

        if (feeToken != ETH) revert CantBeSelfPay();

        vault = vault_;
        manager = manager_;
        executor = executor_;
        receiver = payable(receiver_);
    }

    function sendBackETH(uint256 amount_) external {
        address payable _receiver = receiver;

        if (msg.sender != receiver) {
            revert OnlyReceiver();
        }

        if (address(this).balance < amount_) {
            revert NotEnoughToSendBack();
        }

        _receiver.sendValue(amount_);

        emit SendBackETH(_receiver, amount_);
    }

    function rebalance(bytes[] calldata payloads_)
        external
        nonReentrant
    {
        if (msg.sender != executor) revert OnlyExecutor();

        (uint256 fee, address feeToken) = _getFeeDetails();

        IArrakisStandardManager(manager).rebalance(vault, payloads_);

        _transfer(fee, feeToken);
    }

    receive() external payable {}
}
