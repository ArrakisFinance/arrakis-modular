// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IHOTExecutor {
    //#region errors.

    error AddressZero();
    error SameW3f();
    error UnexpectedReservesAmount0();
    error UnexpectedReservesAmount1();
    error OnlyOwnerOrW3F();

    // #endregion errors.

    // #region events.

    event LogSetW3f(address newW3f);

    // #endregion events.

    function setW3f(address newW3f_) external;

    function setModule(address vault_, address module_, bytes[] calldata payloads_) external;

    function rebalance(
        address vault_,
        bytes[] calldata payloads_,
        uint256 expectedReservesAmount_,
        bool zeroToOne_
    ) external;

    // #region view functions.

    function manager() external view returns (address);
    function w3f() external view returns (address);

    // #endregion view functions.
}
