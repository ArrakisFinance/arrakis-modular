// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHOTCoordinator {
    // #region errors.

    error AddressZero();
    error OnlyResponder();
    error SameResponder();
    error EmptyData();
    error CallFailed();
    error IncreaseMaxVolume();

    // #endregion errors.

    // #region events.

    event LogSetResponder(address oldResponder, address newResponder);
    event LogSetTimelock(address oldTimelock, address newTimelock);

    // #endregion events.

    // #region functions.

    function setResponder(
        address newResponder_
    ) external;
    function callHot(address hot_, bytes calldata data_) external;
    function setMaxTokenVolumes(
        address hot_,
        uint256 maxToken0VolumeToQuote_,
        uint256 maxToken1VolumeToQuote_
    ) external;
    function setPause(address hot_, bool value_) external;

    // #endregion functions.

    // #region view functions.

    function responder() external view returns (address);

    // #endregion view functions.
}
