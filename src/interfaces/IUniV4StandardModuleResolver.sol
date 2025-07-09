// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IUniV4StandardModuleResolver {
    // #region errors.

    error MaxAmountsTooLow();
    error AddressZero();
    error MintZero();
    error NotSupported();
    error AmountsOverMaxAmounts();

    // #endregion errors.

    // #region view/pure functions.

    function poolManager() external returns (address);

    function computeMintAmounts(
        uint256 current0_,
        uint256 current1_,
        uint256 totalSupply_,
        uint256 amount0Max_,
        uint256 amount1Max_
    ) external pure returns (uint256 mintAmount);

    // #endregion view/pure functions.
}
