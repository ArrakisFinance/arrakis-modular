// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract RouterMock {
    uint256 public shareToMint;
    uint256 public amount0ToDeposit;
    uint256 public amount1ToDeposit;

    function setAmounts(
        uint256 shareToMint_,
        uint256 amount0ToDeposit_,
        uint256 amount1ToDeposit_
    ) external {
        shareToMint = shareToMint_;
        amount0ToDeposit = amount0ToDeposit_;
        amount1ToDeposit = amount1ToDeposit_;
    }

    /// @notice getMintAmounts used to get the shares we can mint from some max amounts.
    /// @param vault_ meta vault address.
    /// @param maxAmount0_ maximum amount of token0 user want to contribute.
    /// @param maxAmount1_ maximum amount of token1 user want to contribute.
    /// @return shareToMint maximum amount of share user can get for 'maxAmount0_' and 'maxAmount1_'.
    /// @return amount0ToDeposit amount of token0 user should deposit into the vault for minting 'shareToMint'.
    /// @return amount1ToDeposit amount of token1 user should deposit into the vault for minting 'shareToMint'.
    function getMintAmounts(
        address vault_,
        uint256 maxAmount0_,
        uint256 maxAmount1_
    ) external view returns (uint256, uint256, uint256) {
        return (shareToMint, amount0ToDeposit, amount1ToDeposit);
    }
}
