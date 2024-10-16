// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.19;

import {IHOTExecutor} from "../interfaces/IHOTExecutor.sol";
import {IArrakisStandardManager} from
    "../interfaces/IArrakisStandardManager.sol";
import {IArrakisMetaVault} from "../interfaces/IArrakisMetaVault.sol";
import {IValantisHOTModule} from
    "../interfaces/IValantisHOTModule.sol";

import {Ownable} from "@solady/contracts/auth/Ownable.sol";

contract HOTExecutor is IHOTExecutor, Ownable {
    address public immutable manager;

    address public w3f;

    modifier onlyOwnerOrW3F() {
        if (msg.sender != owner() && msg.sender != w3f) {
            revert OnlyOwnerOrW3F();
        }
        _;
    }

    constructor(address manager_, address w3f_, address owner_) {
        if (
            manager_ == address(0) || w3f_ == address(0)
                || owner_ == address(0)
        ) {
            revert AddressZero();
        }

        manager = manager_;
        w3f = w3f_;
        _initializeOwner(owner_);

        emit LogSetW3f(w3f_);
    }

    function setW3f(
        address newW3f_
    ) external onlyOwner {
        if (newW3f_ == address(0)) {
            revert AddressZero();
        }

        if (newW3f_ == w3f) {
            revert SameW3f();
        }

        w3f = newW3f_;

        emit LogSetW3f(newW3f_);
    }

    function setModule(
        address vault_,
        address module_,
        bytes[] calldata payloads_
    ) external onlyOwnerOrW3F {
        IArrakisStandardManager(manager).setModule(
            vault_, module_, payloads_
        );
    }

    function rebalance(
        address vault_,
        bytes[] calldata payloads_,
        uint256 expectedReservesAmount_,
        bool zeroToOne_
    ) external onlyOwnerOrW3F {
        uint256 length = payloads_.length;
        for (uint256 i; i < length; i++) {
            bytes4 selector = bytes4(payloads_[i][0:4]);

            if (selector == IValantisHOTModule.swap.selector) {
                (uint256 amount0, uint256 amount1) =
                    IArrakisMetaVault(vault_).totalUnderlying();

                if (zeroToOne_) {
                    if (amount0 < expectedReservesAmount_) {
                        revert UnexpectedReservesAmount0();
                    }
                } else {
                    if (amount1 < expectedReservesAmount_) {
                        revert UnexpectedReservesAmount1();
                    }
                }
                break;
            }
        }

        IArrakisStandardManager(manager).rebalance(vault_, payloads_);
    }
}
