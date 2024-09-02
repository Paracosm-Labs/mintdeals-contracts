// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MerkleDistributorStub {
    event Claimed(uint256 merkleIndex, uint256 index, uint256 amount, address claimer);

    mapping(uint256 => mapping(uint256 => bool)) public isClaimed;
    mapping(address => uint256) public balances;

    // New variable to set the required proof length
    uint256 public requiredProofLength = 10;

    function claim(uint256 merkleIndex, uint256 index, uint256 amount, bytes32[] calldata merkleProof) external {
        require(!isClaimed[merkleIndex][index], "MerkleDistributorStub: Drop already claimed.");
        
        // Simple check to make the merkleProof relevant
        require(merkleProof.length == requiredProofLength, "MerkleDistributorStub: Invalid proof length");

        // Mark as claimed
        isClaimed[merkleIndex][index] = true;

        // Transfer tokens (in this stub, we just increase the balance)
        balances[msg.sender] += amount;

        // Emit event
        emit Claimed(merkleIndex, index, amount, msg.sender);
    }

    function hasClaimed(uint256 merkleIndex, uint256 index) external view returns (bool) {
        return isClaimed[merkleIndex][index];
    }

    function balanceOf(address account) external view returns (uint256) {
        return balances[account];
    }

    function setBalance(address account, uint256 amount) external {
        balances[account] = amount;
    }

    // New function to set the required proof length
    function setRequiredProofLength(uint256 length) external {
        requiredProofLength = length;
    }
}