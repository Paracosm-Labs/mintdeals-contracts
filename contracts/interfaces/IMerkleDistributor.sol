// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IMerkleDistributor {
    function claim(uint256 merkleIndex, uint256 index, uint256 amount, bytes32[] calldata merkleProof) external;
}
