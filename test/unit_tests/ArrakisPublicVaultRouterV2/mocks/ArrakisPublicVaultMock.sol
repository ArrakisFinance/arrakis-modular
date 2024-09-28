// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {NATIVE_COIN} from "../../../../src/constants/CArrakis.sol";
import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ArrakisPublicVaultMock is ERC20 {
    address public manager;
    IERC20 public token0;
    IERC20 public token1;

    uint256 public init0;
    uint256 public init1;

    IArrakisLPModule public module;

    uint256 public amount0ToTake;
    uint256 public amount1ToTake;

    uint256 public amount0ToGive;
    uint256 public amount1ToGive;

    constructor() ERC20("Test LP Token", "TLT") {}

    function setAmountToTake(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0ToTake = amount0_;
        amount1ToTake = amount1_;
    }

    function setAmountToGive(
        uint256 amount0_,
        uint256 amount1_
    ) external {
        amount0ToGive = amount0_;
        amount1ToGive = amount1_;
    }

    function setModule(address module_) external {
        module = IArrakisLPModule(module_);
    }

    function mintLPToken(
        address receiver_,
        uint256 amount_
    ) external {
        _mint(receiver_, amount_);
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

    function mint(
        uint256,
        address
    ) external payable returns (uint256 amount0, uint256 amount1) {
        amount0 = amount0ToTake;
        amount1 = amount1ToTake;
        if (address(token0) == NATIVE_COIN) {
            require(amount0ToTake == msg.value);
        } else {
            token0.transferFrom(
                msg.sender, address(this), amount0ToTake
            );
        }
        if (address(token1) == NATIVE_COIN) {
            require(amount1ToTake == msg.value);
        } else {
            token1.transferFrom(
                msg.sender, address(this), amount1ToTake
            );
        }
    }

    function burn(
        uint256 burnAmount_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        amount0 = amount0ToGive;
        amount1 = amount1ToGive;
        _burn(msg.sender, burnAmount_);
        if (address(token0) == NATIVE_COIN && amount0 > 0) {
            payable(receiver_).transfer(amount0);
        } else {
            token0.transfer(receiver_, amount0);
            amount0 = amount0 / 2; // buggy here on puporse to trigger a ReceivedBelowMinimum revert on router
        }
        if (address(token1) == NATIVE_COIN && amount1 > 0) {
            payable(receiver_).transfer(amount1);
        } else {
            token1.transfer(receiver_, amount1);
        }
    }
}
