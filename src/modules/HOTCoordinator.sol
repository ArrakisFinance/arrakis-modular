// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IHOTCoordinator} from "../interfaces/IHOTCoordinator.sol";

import {IHOT} from "@valantis-hot/contracts/interfaces/IHOT.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

/// @dev owner should a timelock contract.
contract HOTCoordinator is IHOTCoordinator, Ownable {
    // #region properties.

    /// @dev responder should not be a timelock contract.
    address public responder;

    // #endregion properties.

    // #region modifiers.

    modifier onlyResponder() {
        if (msg.sender != responder) {
            revert OnlyResponder();
        }
        _;
    }

    // #endregion modifiers.

    constructor(address responder_, address owner_) {
        if (responder_ == address(0) || owner_ == address(0)) {
            revert AddressZero();
        }

        responder = responder_;
        _initializeOwner(owner_);
    }

    // #region functions.

    function setResponder(
        address newResponder_
    ) external onlyOwner {
        address _responder = responder;
        if (newResponder_ == address(0)) {
            revert AddressZero();
        }
        if (newResponder_ == _responder) {
            revert SameResponder();
        }

        responder = newResponder_;

        emit LogSetResponder(_responder, newResponder_);
    }

    function callHot(
        address hot_,
        bytes calldata data_
    ) external onlyOwner {
        if (hot_ == address(0)) {
            revert AddressZero();
        }
        if (data_.length == 0) {
            revert EmptyData();
        }

        (bool success,) = hot_.call(data_);
        if (!success) {
            revert CallFailed();
        }
    }

    function setMaxTokenVolumes(
        address hot_,
        uint256 maxToken0VolumeToQuote_,
        uint256 maxToken1VolumeToQuote_
    ) external onlyResponder {
        IHOT(hot_).setMaxTokenVolumes(
            maxToken0VolumeToQuote_, maxToken1VolumeToQuote_
        );
    }

    function setPause(
        address hot_,
        bool value_
    ) external onlyResponder {
        IHOT(hot_).setPause(value_);
    }

    // #endregion functions.
}
