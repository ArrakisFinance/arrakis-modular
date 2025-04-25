// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

contract VaultMock {
    address public token0;
    address public token1;

    uint256 internal _amount0;
    uint256 internal _amount1;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    // #region mock functions.

    function setAmounts(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        _amount0 = amount0_;
        _amount1 = amount1_;
    }

    // #endregion mock functions.

    function module() external view returns (IArrakisLPModule) {
        return IArrakisLPModule(address(0));
    }

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        return (_amount0, _amount1);
    }

    function depositors() external view returns (address[] memory) {
        return new address[](0);
    }
}
