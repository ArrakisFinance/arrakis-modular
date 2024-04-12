// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IArrakisLPModule} from
    "../../../../src/interfaces/IArrakisLPModule.sol";
import {BASE} from "../../../../src/constants/CArrakis.sol";

import {EnumerableSet} from
    "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {FullMath} from "@v3-lib-0.8/contracts/FullMath.sol";

contract ArrakisMetaVaultPrivateMock {
    using EnumerableSet for EnumerableSet.AddressSet;

    address public token0;
    address public token1;
    IArrakisLPModule public module;

    EnumerableSet.AddressSet internal _whitelistedModules;

    EnumerableSet.AddressSet internal _depositors;

    function setTokens(address token0_, address token1_) external {
        token0 = token0_;
        token1 = token1_;
    }

    function setModule(address module_) external {
        module = IArrakisLPModule(module_);
    }

    function whitelistModules(
        address[] calldata beacons_,
        bytes[] calldata
    ) external {
        for (uint256 i; i < beacons_.length; i++) {
            _whitelistedModules.add(beacons_[i]);
        }
    }

    function blacklistModules(address[] calldata beacons_) external {
        for (uint256 i; i < beacons_.length; i++) {
            _whitelistedModules.remove(beacons_[i]);
        }
    }

    function whitelistDepositors(address[] calldata depositors_)
        external
    {
        for (uint256 i; i < depositors_.length; i++) {
            _depositors.add(depositors_[i]);
        }
    }

    function blacklistDepositors(address[] calldata depositors_)
        external
    {
        for (uint256 i; i < depositors_.length; i++) {
            _depositors.remove(depositors_[i]);
        }
    }

    function deposit(
        uint256 amount0_,
        uint256 amount1_
    ) external payable {
        IERC20(token0).transferFrom(
            msg.sender, address(this), amount0_
        );
        IERC20(token1).transferFrom(
            msg.sender, address(this), amount1_
        );
    }

    function withdraw(
        uint256 proportion_,
        address receiver_
    ) external returns (uint256 amount0, uint256 amount1) {
        uint256 currentBalance0 =
            IERC20(token0).balanceOf(address(this));
        uint256 currentBalance1 =
            IERC20(token1).balanceOf(address(this));

        amount0 = FullMath.mulDiv(proportion_, currentBalance0, BASE);
        amount1 = FullMath.mulDiv(proportion_, currentBalance1, BASE);

        IERC20(token0).transfer(receiver_, amount0);
        IERC20(token1).transfer(receiver_, amount1);
    }
}
