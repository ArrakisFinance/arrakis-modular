// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {IPauser} from "./interfaces/IPauser.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IPausable} from "./interfaces/IPausable.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract Pauser is IPauser, Ownable {
    using EnumerableSet for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet internal _pausers;

    constructor(address pauser_, address owner_) {
        if (pauser_ == address(0) || owner_ == address(0)) {
            revert AddressZero();
        }
        _pausers.add(pauser_);

        _initializeOwner(owner_);
    }

    function pause(address target_) external override {
        if (!_pausers.contains(msg.sender)) revert OnlyPauser();

        IPausable(target_).pause();

        emit LogPause(target_);
    }

    function whitelistPausers(
        address[] calldata pausers_
    ) external override onlyOwner {
        for (uint256 i = 0; i < pausers_.length; i++) {
            if (pausers_[i] == address(0)) revert AddressZero();
            if (_pausers.contains(pausers_[i])) {
                revert AlreadyPauser();
            }
            _pausers.add(pausers_[i]);
        }

        emit LogPauserWhitelisted(pausers_);
    }

    function blacklistPausers(
        address[] calldata pausers_
    ) external override onlyOwner {
        for (uint256 i = 0; i < pausers_.length; i++) {
            if (!_pausers.contains(pausers_[i])) revert NotPauser();
            _pausers.remove(pausers_[i]);
        }

        emit LogPauserBlacklisted(pausers_);
    }

    function isPauser(address account_) public view returns (bool) {
        return _pausers.contains(account_);
    }
}
