// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

interface ISelfPay {
    // #region errors.

    error AddressZero();
    error CantBeSelfPay();
    error NotEnoughToSendBack();
    error OnlyExecutor();
    error OnlyReceiver();

    // #endregion errors.

    // #region events.

    event SendBackETH(address receiver, uint256 amount);

    // #endregion events.
}