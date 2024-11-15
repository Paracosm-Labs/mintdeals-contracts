// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol"; // EIP-2981 implementation
import "@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol";
import "./AdminAuth.sol";

/**
 * @title MintDealsNFT
 * @dev ERC721 contract for MintDeals NFTs with off-chain validation and on-chain redemption.
 */
contract MintDealsNFT is ERC721, ERC2981, IERC721Enumerable, AdminAuth {
    uint256 public nextTokenId;
    mapping(uint256 => string) private _tokenURIs;
    mapping(uint256 => uint256) public dealIds; // Mapping from tokenId to dealId
    mapping(uint256 => bool) public redemptionRequests; // Track redemption requests

    address public royaltyRecipient; // Admin-configured royalty recipient
    uint96 public royaltyPercentage; // Admin-configured royalty percentage (basis points)

    // Token enumeration storage
    uint256[] private _allTokens;
    mapping(address => mapping(uint256 => uint256)) private _ownedTokens;
    mapping(uint256 => uint256) private _ownedTokensIndex;
    mapping(uint256 => uint256) private _allTokensIndex;

    // Events
    event NFTMinted(address indexed recipient, uint256 indexed tokenId, uint256 indexed clubId, uint256 dealId, string metadataURI);
    event NFTRedeemed(uint256 indexed tokenId, uint256 indexed dealId);
    event RedeemRequest(address indexed holder, uint256 indexed tokenId);
    event RoyaltyInfoUpdated(address indexed recipient, uint96 percentage);


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

    // IERC721Enumerable functions
    function totalSupply() public view override returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) public view override returns (uint256) {
        require(index < totalSupply(), "Index out of bounds");
        return _allTokens[index];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) public view override returns (uint256) {
        require(index < balanceOf(owner), "Index out of bounds");
        return _ownedTokens[owner][index];
    }

    // Internal function to add a token to the allTokens array and update indices
    function _addTokenToAllTokensEnumeration(uint256 tokenId) private {
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);
    }

    // Internal function to add a token to an owner's list of tokens
    function _addTokenToOwnerEnumeration(address to, uint256 tokenId) private {
        _ownedTokensIndex[tokenId] = balanceOf(to) - 1;
        _ownedTokens[to][_ownedTokensIndex[tokenId]] = tokenId;
    }

    // Internal function to remove a token from owner's list
    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = balanceOf(from) - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        delete _ownedTokensIndex[tokenId];
        delete _ownedTokens[from][lastTokenIndex];
    }

    // Internal function to remove a token from the allTokens array
    function _removeTokenFromAllTokensEnumeration(uint256 tokenId) private {
        uint256 lastTokenIndex = _allTokens.length - 1;
        uint256 tokenIndex = _allTokensIndex[tokenId];

        uint256 lastTokenId = _allTokens[lastTokenIndex];
        _allTokens[tokenIndex] = lastTokenId;
        _allTokensIndex[lastTokenId] = tokenIndex;

        delete _allTokensIndex[tokenId];
        _allTokens.pop();
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
    function mintNFT(address recipient, uint256 clubId, uint256 dealId, string memory metadataURI) external onlyAdmin(msg.sender) returns (uint256) {
        uint256 tokenId = nextTokenId++;
        _mint(recipient, tokenId);
        _setTokenURI(tokenId, metadataURI);
        dealIds[tokenId] = dealId;

        // Set the royalty info for this token, using admin-configured values
        _setTokenRoyalty(tokenId, royaltyRecipient, royaltyPercentage);

        // Add to enumerations
        _addTokenToAllTokensEnumeration(tokenId);
        _addTokenToOwnerEnumeration(recipient, tokenId);

        emit NFTMinted(recipient, tokenId, clubId, dealId, metadataURI);
        return tokenId;
    }

    /**
     * @notice Mints multiple NFTs for a single recipient, club, and deal.
     * @dev Only callable by an admin.
     * Uses the admin-configured royalty recipient and percentage.
     * @param recipient The address of the NFT recipient.
     * @param clubId The ID of the club associated with the NFTs.
     * @param dealId The ID of the deal associated with the NFTs.
     * @param metadataURI The URI containing metadata for the NFTs.
     * @param quantity The number of NFTs to mint.
     * @return An array of the newly minted NFT IDs.
     */
    function batchMintNFTs(
        address recipient,
        uint256 clubId,
        uint256 dealId,
        string memory metadataURI,
        uint256 quantity
    ) external onlyAdmin(msg.sender) returns (uint256[] memory) {
        require(quantity > 0, "Quantity must be greater than zero");

        uint256[] memory newTokenIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = nextTokenId++;
            _mint(recipient, tokenId);
            _setTokenURI(tokenId, metadataURI);
            dealIds[tokenId] = dealId;

            // Set the royalty info for this token, using admin-configured values
            _setTokenRoyalty(tokenId, royaltyRecipient, royaltyPercentage);

            // Add to enumerations
            _addTokenToAllTokensEnumeration(tokenId);
            _addTokenToOwnerEnumeration(recipient, tokenId);

            emit NFTMinted(recipient, tokenId, clubId, dealId, metadataURI);
            newTokenIds[i] = tokenId;
        }

        return newTokenIds;
    }

    /**
     * @notice Requests the redemption of an NFT.
     * @dev The NFT owner must call this function to initiate the redemption process.
     * @param tokenId The ID of the NFT to be redeemed.
     */
    function requestRedemption(uint256 tokenId) external {
        require(ownerOf(tokenId) == msg.sender, "Not the token owner");
        redemptionRequests[tokenId] = true;

        emit RedeemRequest(msg.sender, tokenId);
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
     * @notice Returns the royalty information for a given token.
     * @dev Overrides the default royaltyInfo function to use the admin-configured recipient and percentage.
     * @param tokenId The ID of the token to query.
     * @param salePrice The sale price of the token.
     * @return receiver The royalty recipient address.
     * @return royaltyAmount The royalty amount based on the sale price.
     */
    function royaltyInfo(uint256 tokenId, uint256 salePrice) public view override returns (address receiver, uint256 royaltyAmount) {
        (receiver, royaltyAmount) = super.royaltyInfo(tokenId, salePrice);
    }

    /**
     * @notice Supports multiple interfaces including IERC721Enumerable and ERC2981.
     * @dev Required to support the IERC721Enumerable and ERC2981 standards.
     * @param interfaceId The interface ID to check.
     * @return True if the interface is supported, false otherwise.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC2981, ERC721, IERC165) returns (bool) {
        return interfaceId == type(IERC721Enumerable).interfaceId || super.supportsInterface(interfaceId);
    }
}
