// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IGuardian} from "./interfaces/IGuardian.sol";
import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract Guardian is Ownable, IGuardian {
    // #region public properties.

    address public pauser;

    // #endregion public properties.

    constructor(address owner_, address pauser_) {
        if (owner_ == address(0) || pauser_ == address(0)) revert AddressZero();
        _initializeOwner(owner_);
        pauser = pauser_;

        emit LogSetPauser(address(0), pauser_);
    }

    // #region state modifying functions.

    /// @notice function to set the pauser of Arrakis protocol.
    function setPauser(address newPauser_) external onlyOwner {
        if (newPauser_ == address(0)) revert AddressZero();

        emit LogSetPauser(pauser, pauser = newPauser_);
    }

    // #endregion state modifying functions.
}
