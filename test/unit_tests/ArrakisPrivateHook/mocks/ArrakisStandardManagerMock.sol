// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {IOracleWrapper} from
    "../../../../src/interfaces/IOracleWrapper.sol";

contract ArrakisStandardManagerMock {
    address internal _executor;

    function setExecutor(address executor_) external {
        _executor = executor_;
    }

    function vaultInfo(
        address vault_
    )
        external
        view
        returns (
            uint256 lastRebalance,
            uint256 cooldownPeriod,
            IOracleWrapper oracle,
            uint24 maxDeviation,
            address executor,
            address stratAnnouncer,
            uint24 maxSlippagePIPS,
            uint24 managerFeePIPS
        )
    {
        executor = _executor;
    }
}
