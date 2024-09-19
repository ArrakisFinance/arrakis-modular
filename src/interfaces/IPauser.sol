// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface IPauser {
    // #region errors.

    error AddressZero();
    error AlreadyPauser();
    error NotPauser();
    error OnlyPauser();

    // #endregion errors.

    // #region events.

    event LogPauserWhitelisted(address[] indexed pauser);
    event LogPauserBlacklisted(address[] indexed pauser);
    event LogPause(address indexed target);

    // #endregion events.

    // #region state modifying functions.

    function pause(address target_) external;
    function whitelistPausers(address[] calldata pausers_) external;
    function blacklistPausers(address[] calldata pausers_) external;

    // #endregion state modifying functions.

    function isPauser(address account) external view returns (bool);
}
