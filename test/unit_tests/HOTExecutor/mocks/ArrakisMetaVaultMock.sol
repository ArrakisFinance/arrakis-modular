// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract ArrakisMetaVaultMock {
    uint256 public amount0;
    uint256 public amount1;

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0 = amount0_;
        amount1 = amount1_;
    }

    function totalUnderlying()
        external
        view
        returns (uint256, uint256)
    {
        return (amount0, amount1);
    }
}
