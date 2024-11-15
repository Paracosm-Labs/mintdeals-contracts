// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface IMintDealsNFT {
    function mintNFT(address recipient, uint256 clubId, uint256 dealId, string memory metadataURI) external returns (uint256);
    function batchMintNFTs(address recipient, uint256 clubId, uint256 dealId, string memory metadataURI, uint256 quantity) external returns (uint256[] memory);
    function redeemNFT(uint256 dealId) external;
    function requestRedemption(uint256 tokenId) external;
    function approveRedemption(uint256 tokenId) external;
}
