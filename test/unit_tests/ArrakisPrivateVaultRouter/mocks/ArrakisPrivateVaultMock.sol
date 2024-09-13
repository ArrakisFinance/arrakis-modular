// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NATIVE_COIN} from "../../../../src/constants/CArrakis.sol";
import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";
import {BASE} from "../../../../src/constants/CArrakis.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract ArrakisPrivateVaultMock {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public manager;
    IERC20 public token0;
    IERC20 public token1;

    uint256 public init0;
    uint256 public init1;

    IArrakisLPModule public module;

    // #region internal properties.

    EnumerableSet.AddressSet internal _depositors;

    // #endregion internal properties.

    // #region view functions.

    function depositors() external view returns (address[] memory) {
        return _depositors.values();
    }

    // #endregion view functions.

    // #region mock functions.

    function addDepositor(address depositor_) external {
        _depositors.add(depositor_);
    }

    function removeDepositor(address depositor_) external {
        _depositors.remove(depositor_);
    }

    function setModule(address module_) external {
        module = IArrakisLPModule(module_);
    }

    function setInits(uint256 init0_, uint256 init1_) external {
        init0 = init0_;
        init1 = init1_;
    }

    function setTokens(address token0_, address token1_) external {
        token0 = IERC20(token0_);
        token1 = IERC20(token1_);
    }

    function setManager(address manager_) external {
        manager = manager_;
    }

    // #endregion mock functions.

    function totalUnderlying()
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (address(token0) == NATIVE_COIN) {
            amount0 = address(this).balance;
        } else {
            amount0 = token0.balanceOf(address(this));
        }

        if (address(token1) == NATIVE_COIN) {
            amount1 = address(this).balance;
        } else {
            amount1 = token1.balanceOf(address(this));
        }
    }

    function getInits() external view returns (uint256, uint256) {
        return (init0, init1);
    }

    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable virtual {
        if (address(token0) == NATIVE_COIN) {
            require(amount0_ == msg.value);
        } else {
            token0.transferFrom(msg.sender, address(this), amount0_);
        }
        if (address(token1) == NATIVE_COIN) {
            require(amount1_ == msg.value);
        } else {
            token1.transferFrom(msg.sender, address(this), amount1_);
        }
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external virtual returns (uint256 amount0, uint256 amount1) {
        amount0 = address(token0) == NATIVE_COIN
            ? address(this).balance
            : token0.balanceOf(address(this));
        amount1 = address(token1) == NATIVE_COIN
            ? address(this).balance
            : token1.balanceOf(address(this));

        amount0 = FullMath.mulDiv(amount0, proportion_, BASE);
        amount1 = FullMath.mulDiv(amount1, proportion_, BASE);

        if (address(token0) == NATIVE_COIN && amount0 > 0) {
            payable(receiver_).transfer(amount0);
        } else {
            token0.transfer(receiver_, amount0);
            // buggy here on puporse to trigger a ReceivedBelowMinimum revert on router.
            amount0 = amount0 / 2;
        }
        if (address(token1) == NATIVE_COIN && amount1 > 0) {
            payable(receiver_).transfer(amount1);
        } else {
            token1.transfer(receiver_, amount1);
        }
    }
}
