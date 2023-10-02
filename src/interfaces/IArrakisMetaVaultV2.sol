// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

interface IArrakisMetaVaultV2 {
    // #region events.

    event LogSetModule(address module, bytes[] payloads_);

    // #endregion events.

    /// @notice function used to set module
    /// @param module_ address of the new module
    /// @param payloads_ datas to initialize/rebalance on the new module
    function setModule(address module_, bytes[] calldata payloads_) external;
}

