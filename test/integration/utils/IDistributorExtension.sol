// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import {IDistributor} from "../../../src/interfaces/IDistributor.sol";

interface IDistributorExtension is IDistributor {
    struct MerkleTree {
        bytes32 merkleRoot;
        bytes32 ipfsHash;
    }

    function updateTree(
        MerkleTree calldata _tree
    ) external;

    function disputer() external view returns (address);

    function endOfDisputePeriod() external view returns (uint48);
}
