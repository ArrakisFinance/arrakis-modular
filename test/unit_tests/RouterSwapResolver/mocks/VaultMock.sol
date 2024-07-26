// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

contract VaultMock {
    address public token0;
    address public token1;

    uint256 public init0;
    uint256 public init1;
    uint256 public amount0;
    uint256 public amount1;

    function setTokens(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0 = amount0_;
        amount1 = amount1_;
    }

    function setInits(uint256 init0_, uint256 init1_) external {
        init0 = init0_;
        init1 = init1_;
    }

    /// @notice function used to get the initial amounts needed to open a position.
    /// @return init0 the amount of token0 needed to open a position.
    /// @return init1 the amount of token1 needed to open a position.
    function getInits() external view returns (uint256, uint256) {
        return (init0, init1);
    }

    /// @notice function used to get the amount of token0 and token1 sitting
    /// on the position.
    /// @return amount0 the amount of token0 sitting on the position.
    /// @return amount1 the amount of token1 sitting on the position.
    function totalUnderlying()
        external
        view
        returns (uint256, uint256)
    {
        return (amount0, amount1);
    }
}
