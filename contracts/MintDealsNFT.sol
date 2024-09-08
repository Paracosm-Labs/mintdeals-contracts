// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol"; // EIP-2981 implementation
import "./AdminAuth.sol";

/**
 * @title MintDealsNFT
 * @dev ERC721 contract for MintDeals NFTs with off-chain validation and on-chain redemption.
 */
contract MintDealsNFT is ERC721, ERC2981, AdminAuth {
    uint256 public nextTokenId;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) public dealIds; // Mapping from tokenId to dealId
    mapping(uint256 => bool) public redemptionRequests; // Track redemption requests

    address public royaltyRecipient; // Admin-configured royalty recipient
    uint96 public royaltyPercentage; // Admin-configured royalty percentage (basis points)

    event NFTMinted(address recipient, uint256 tokenId, uint256 dealId, string metadataURI);
    event NFTRedeemed(uint256 tokenId, uint256 dealId);
    event RoyaltyInfoUpdated(address recipient, uint96 percentage);

    /**
     * @dev Constructor for the MintDealsNFT contract.
     * Initializes the ERC721 contract with the name "MintDeals" and symbol "DEAL".
     * Sets the initial royalty recipient and percentage.
     */
    constructor(address _initialRoyaltyRecipient, uint96 _initialRoyaltyPercentage) ERC721("MintDeals", "DEAL") {
        require(_initialRoyaltyPercentage <= 10000, "Percentage too high");
        nextTokenId = 1;
        royaltyRecipient = _initialRoyaltyRecipient;
        royaltyPercentage = _initialRoyaltyPercentage;
    }

    /**
     * @notice Updates the royalty recipient and percentage.
     * @dev Only callable by an admin.
     * @param _recipient The new royalty recipient address.
     * @param _percentage The new royalty percentage (in basis points).
     */
    function updateRoyaltyInfo(address _recipient, uint96 _percentage) external onlyAdmin(msg.sender) {
        require(_percentage <= 10000, "Percentage must be <= 100%");
        royaltyRecipient = _recipient;
        royaltyPercentage = _percentage;
        emit RoyaltyInfoUpdated(_recipient, _percentage);
    }

    /**
     * @notice Mints a new NFT for a given recipient.
     * @dev Only callable by an admin.
     * Uses the admin-configured royalty recipient and percentage.
     * @param recipient The address of the NFT recipient.
     * @param dealId The ID associated with the deal for this NFT.
     * @param metadataURI The URI containing metadata for the NFT.
     * @return tokenId The ID of the newly minted NFT.
     */
    function mintNFT(
        address recipient,
        uint256 dealId,
        string memory metadataURI
    ) external onlyAdmin(msg.sender) returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, metadataURI);
        dealIds[tokenId] = dealId;

        // Set the royalty info for this token, using admin-configured values
        _setTokenRoyalty(tokenId, royaltyRecipient, royaltyPercentage);

        emit NFTMinted(recipient, tokenId, dealId, metadataURI);
        return tokenId;
    }

    /**
     * @notice Requests the redemption of an NFT.
     * @dev The NFT owner must call this function to initiate the redemption process.
     * @param tokenId The ID of the NFT to be redeemed.
     */
    function requestRedemption(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        redemptionRequests[tokenId] = true;
    }

    /**
     * @notice Approves the redemption of an NFT.
     * @dev Only callable by an admin. The NFT is burned upon approval.
     * @param tokenId The ID of the NFT to be redeemed.
     */
    function approveRedemption(uint256 tokenId) external onlyAdmin(msg.sender) {
        require(redemptionRequests[tokenId], "Redemption not requested or already processed");
        _burn(tokenId);
        delete redemptionRequests[tokenId];

        emit NFTRedeemed(tokenId, dealIds[tokenId]);
    }

    /**
     * @notice Rejects the redemption of an NFT.
     * @dev Only callable by an admin. The redemption request is canceled.
     * @param tokenId The ID of the NFT for which redemption is rejected.
     */
    function rejectRedemption(uint256 tokenId) external onlyAdmin(msg.sender) {
        require(redemptionRequests[tokenId], "Redemption not requested or already processed");
        delete redemptionRequests[tokenId];
    }

    /**
     * @notice Sets the token URI for a given token.
     * @dev Internal function to set the metadata URI for a specific tokenId.
     * @param tokenId The ID of the token for which to set the URI.
     * @param _tokenURI The URI string to be set.
     */
    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal virtual {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI set of nonexistent token");
        _tokenURIs[tokenId] = _tokenURI;
    }

    /**
     * @notice Returns the token URI for a given token.
     * @dev Retrieves the metadata URI for a specific tokenId.
     * @param tokenId The ID of the token to query.
     * @return The metadata URI string for the token.
     */
    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        require(ownerOf(tokenId) != address(0), "ERC721Metadata: URI query for nonexistent token");
        return _tokenURIs[tokenId];
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
