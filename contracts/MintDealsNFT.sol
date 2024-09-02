// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./AdminAuth.sol";

contract MintDealsNFT is ERC721, AdminAuth {
    uint256 public nextTokenId;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) public dealIds; // Mapping from tokenId to dealId
    mapping(uint256 => bool) public redemptionRequests; // Track redemption requests

    event NFTMinted(address recipient, uint256 tokenId, uint256 dealId, string metadataURI);
    event NFTRedeemed(uint256 tokenId, uint256 dealId);

    constructor() ERC721("MintDealsNFT", "DEAL") {}

    // Function to mint a new NFT
    function mintNFT(address recipient, uint256 dealId, string memory metadataURI) external onlyAdmin(msg.sender) returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, metadataURI);
        dealIds[tokenId] = dealId;

        emit NFTMinted(recipient, tokenId, dealId, metadataURI);
        return tokenId;
    }

    // Function to request redemption of an NFT
    function requestRedemption(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        redemptionRequests[tokenId] = true;
    }

    // Function to approve redemption (burn the NFT)
    function approveRedemption(uint256 tokenId) external onlyAdmin(msg.sender) {
        require(redemptionRequests[tokenId], "Redemption not requested or already processed");
        _burn(tokenId);
        delete redemptionRequests[tokenId];

        emit NFTRedeemed(tokenId, dealIds[tokenId]);
    }

    // Function to reject redemption
    function rejectRedemption(uint256 tokenId) external onlyAdmin(msg.sender) {
        require(redemptionRequests[tokenId], "Redemption not requested or already processed");
        delete redemptionRequests[tokenId];
    }

    // Function to set the token URI
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    // Function to retrieve the token URI
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }
}
