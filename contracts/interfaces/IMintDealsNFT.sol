// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IMintDealsNFT {
    function mintNFT(address recipient, uint256 dealId, string memory ipfsMetadataURI) external returns (uint256);
    function redeemNFT(uint256 dealId) external;
    function requestRedemption(uint256 tokenId) external;
    function approveRedemption(uint256 tokenId) external;
}
