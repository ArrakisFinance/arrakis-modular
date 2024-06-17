// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

interface ISimpleSelfPay {
    // #region errors.

    error AddressZero();
    error CantBeSelfPay();
    error NotEnoughToSendBack();
    error OnlyExecutor();

    // #endregion errors.

    // #region events.

    event SendBackETH(address receiver, uint256 amount);

    // #endregion events.
}
