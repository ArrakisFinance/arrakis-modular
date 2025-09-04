// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IPancakeDistributor} from "../../../src/interfaces/IPancakeDistributor.sol";

interface IPancakeDistributorExtension is IPancakeDistributor {
    function setMerkleTree(bytes32 root, bytes32 ipfsHash) external;

    function merkleTreeRoot() external view returns (bytes32);

    function claimedAmounts(address token, address user) external view returns (uint256);

    function disputer() external view returns (address);

    function getMerkleTreeRoot() external view returns (bytes32);

    function endOfDisputePeriod() external view returns (uint256);
}
