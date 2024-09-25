// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./AdminAuth.sol";
import "./CreditManager.sol";
import "./interfaces/ICreditFacility.sol";
import "./interfaces/ICreditManager.sol";
import "./interfaces/IMintDealsNFT.sol";

/// @title ClubRegistry - Manages the registration, membership, and deal processing for clubs
/// @notice This contract handles the creation of clubs, adding/removing members, and processing payments with integration to a credit facility.
contract ClubDealRegistry is AdminAuth, ReentrancyGuard{

    // Struct for storing club details
    struct Club {
        uint256 clubId;
        address owner;
        mapping(address => bool) members;
        uint256 memberCount;
        uint256 nextDealId;
        uint256 membershipFee;
        bool active;
        bool sendToCreditFacility; // If true, membership fees go to the credit facility; if false, they go to the club owner's wallet subtract fee.
        mapping(uint256 => Deal) deals;
    }

    // Struct for storing deal details
    struct Deal {
        uint256 dealId;        // Unique identifier for the deal
        uint256 maxSupply;     // Maximum supply of the deal
        uint256 remainingSupply; // Remaining supply of the deal
        uint256 redeemedSupply; // Redeemed supply of the deal
        uint256 expiryDate;    // Expiry date of the deal
        uint256 maxMintsPerMember;  //Field to specify the max mints per member
        mapping(address => uint256) mintsPerMember; // Mapping to track mints per member
        string metadataURI; // IPFS URI for the deal metadata
    }

    mapping(uint256 => Club) public clubs; // Maps each unique club ID to its corresponding Club struct, allowing for easy access and management of club details by ID.
    mapping(uint256 => mapping(uint256 => Deal)) public clubDeals; // separate mapping for deals by club ID
    mapping(address => uint256) public splitForCreditManager; // Accumulated split of membership fees for CreditManager by supported token
    mapping(address => uint256) public collectedFeesByToken; // Mapping to store collected fees for each token address

    
    ICreditFacility public creditFacility; // Reference to the CreditFacility contract
    ICreditManager public creditManager; // Reference to the CreditManager contract
    IMintDealsNFT public mintDealsNFT; // Address of the MintDealsNFT contract

    // club counter
    uint256 private nextClubId;
    address public dealNFTAddress; 

    uint256 public clubCreationFee = 6 * 10**18;  //$6 default Fee charged to create a club in Registry
    uint256 public commissionFee = 8; // Commission fee percentage for direct wallet transfers in %
    uint256 public splitToCreditFacility = 80; // 80% default Split of membership fees going to CreditFacility

    // Events
    event ClubCreated(uint256 indexed clubId, address indexed owner, uint256 membershipFee);
    event MemberAdded(uint256 indexed clubId, address indexed member, uint256 membershipFee);
    event ClubUpdated(uint256 indexed clubId, uint256 membershipFee, bool active);
    event DealCreated(uint256 indexed clubId, uint256 indexed dealId, uint256 maxSupply, uint256 expiryDate, string metadataURI);
    event DealRedemptionConfirmed(uint256 indexed clubId, uint256 indexed dealId, address indexed member);
    event SwappedViaEX(address tokenIn, address tokenOut, uint256 amountOut, address to);
    event txnExecuted(string txnHash);

    constructor(
        address _creditFacilityAddress, 
        address _creditManagerAddress,
        address _mintDealsNFTAddress) {
        creditFacility = ICreditFacility(_creditFacilityAddress); // Initialize the reference to the credit facility contract
        creditManager = ICreditManager(_creditManagerAddress); // Initialize the reference to the credit manager contract
        mintDealsNFT = IMintDealsNFT(_mintDealsNFTAddress); // Initialize the MintDealsNFT address
    }
   
   // Only club owner can perform certain actions
    modifier onlyClubOwner(uint256 _clubId) {
        require(clubs[_clubId].owner == msg.sender, "Not authorized");
        _;
    }

    // Modifier to ensure the caller is a member of the club
    modifier onlyClubMember(uint256 _clubId) {
        require(clubs[_clubId].members[msg.sender], "Not a club member");
        _;
    }

    // fee to create club
    function setClubCreationFee(uint256 _fee) external onlyAdmin(msg.sender) {
        clubCreationFee = _fee;
    }

    // Add a function to update the commission fee
    function setCommissionFee(uint256 _fee) external onlyAdmin(msg.sender) {
        commissionFee = _fee;
    }

    // split to credit facility
    function setSplitToCreditFacility(uint256 _split) external onlyAdmin(msg.sender) {
        splitToCreditFacility = _split;
    }

   /// @notice Create a new club
    function createClub(address _paymentTokenAddress, uint256 _membershipFee, bool _sendToCreditFacility) public nonReentrant returns (uint256) {
        // Check if the token is supported by CreditFacility
        address cTokenAddress = creditFacility.getCTokenAddress(_paymentTokenAddress);
        require(cTokenAddress != address(0), "Unsupported token");

        // Adjust the club creation fee based on the token's decimals
        uint256 adjustedCreationFee = _adjustFeeForDecimals(_paymentTokenAddress, clubCreationFee);

        // Ensure the sender has enough tokens to pay the creation fee
        IERC20 token = IERC20(_paymentTokenAddress);
        require(token.balanceOf(msg.sender) >= adjustedCreationFee, "Insufficient balance to create club");

        // Transfer the creation fee from the sender to the contract
        require(token.transferFrom(msg.sender, address(this), adjustedCreationFee), "Fee transfer failed");

        // Create the club
        uint256 clubId = nextClubId++;
        Club storage newClub = clubs[clubId];
        newClub.clubId = clubId;
        newClub.owner = msg.sender;
        newClub.membershipFee = _membershipFee;
        newClub.nextDealId++;
        newClub.active = true;
        newClub.sendToCreditFacility = _sendToCreditFacility;

        // Update collected fees for the specific token
        collectedFeesByToken[_paymentTokenAddress] += adjustedCreationFee;

        // Register owner in Credit Manager
        creditManager.registerUser(msg.sender);

        emit ClubCreated(clubId, msg.sender, _membershipFee);

        return clubId;
    }

    /// @notice Add a member to a club with payment processing
    /// @param _clubId The ID of the club
    /// @param _newMember The address of the member to add
    /// @param _paymentTokenAddress The payment token for joining the club
    function addClubMember(uint256 _clubId, address _newMember, address _paymentTokenAddress) public nonReentrant {
        Club storage club = clubs[_clubId];

        // Check if the member is already part of the club
        require(!club.members[_newMember], "Member already exists in the club");

        // Check if the club is active
        require(club.active, "Club is not active");

        // Check if the token is supported by CreditFacility
        address cTokenAddress = creditFacility.getCTokenAddress(_paymentTokenAddress);
        require(cTokenAddress != address(0), "Unsupported token");

        // Adjust membership fee based on token decimals
        uint256 adjustedMembershipFee = _adjustFeeForDecimals(_paymentTokenAddress, club.membershipFee);

        // Ensure the sender has enough tokens to pay the membership fee
        IERC20 paymentToken = IERC20(_paymentTokenAddress);
        require(paymentToken.balanceOf(msg.sender) >= adjustedMembershipFee, "Insufficient balance to join club");

        // Transfer the membership fee from the sender to the contract
        require(paymentToken.transferFrom(msg.sender, address(this), adjustedMembershipFee), "Membership fee transfer failed");

        uint256 amtToCreditFacility = adjustedMembershipFee * splitToCreditFacility / 100;
        uint256 amtToCreditManager = adjustedMembershipFee - amtToCreditFacility;

        if (club.sendToCreditFacility) {
            // Send the portion of membership fee to Credit Facility on behalf of the club owner
            uint256 currentAllowance = paymentToken.allowance(address(this), address(creditFacility));
            if (currentAllowance <= amtToCreditFacility) {
                require(paymentToken.approve(address(creditFacility), type(uint256).max), "Approval for Credit Facility failed");
            }
            creditFacility.supplyAsset(cTokenAddress, amtToCreditFacility, club.owner);

            // Update splitForCreditManager
            splitForCreditManager[_paymentTokenAddress] += amtToCreditManager;
        } else {
            // Send portion of membership fee to the owner's wallet minus amount for Credit Manager + commission fee
            uint256 commission = adjustedMembershipFee * commissionFee / 100;
            uint256 newAmtToCreditManager = amtToCreditManager - commission;

            paymentToken.transfer(club.owner, amtToCreditManager);

            // Update splitForCreditManager with the amount intended for Credit Manager
            splitForCreditManager[_paymentTokenAddress] += newAmtToCreditManager;

            // Update collected fees
            collectedFeesByToken[_paymentTokenAddress] += commission;
        }

        // Add member to club
        club.members[_newMember] = true;
        club.memberCount += 1;

        emit MemberAdded(_clubId, _newMember, adjustedMembershipFee);
    }

    // updates club info
    function updateClub(uint256 _clubId, uint256 _membershipFee, bool _active, bool _sendToCreditFacility) external onlyClubOwner(_clubId) returns (uint256){
        Club storage club = clubs[_clubId];

       // Update the club information
        club.membershipFee = _membershipFee;
        club.active = _active;
        club.sendToCreditFacility = _sendToCreditFacility;

        emit ClubUpdated(_clubId, _membershipFee, _active);
        return _clubId;
    }


    /// @notice Check if an address is a member of a club
    /// @param _clubId The ID of the club
    /// @param _address The address to check
    /// @return bool True if the address is a member, false otherwise
    function isMember(uint256 _clubId, address _address) public view returns (bool) {
        return clubs[_clubId].members[_address];
    }

    /// @notice Get the total number of clubs created
    /// @return uint256 The total count of clubs
    function getClubCount() public view returns (uint256) {
        return nextClubId - 1;
    }

    /// @notice Get the number of members in a specific club
    /// @param _clubId The ID of the club
    /// @return uint256 The total count of members in the club
    function getClubMemberCount(uint256 _clubId) public view returns (uint256) {
        return clubs[_clubId].memberCount;
    }

    /// @notice Create a new deal for a club
    function createDeal(uint256 _clubId, uint256 _maxSupply, uint256 _expiryDate, string memory _metadataURI, uint256 _maxMintPerMember) public nonReentrant onlyClubOwner(_clubId) returns (uint256) {
        // Ensure the club exists and is active
        require(clubs[_clubId].active, "Club is not active");
        require(_maxMintPerMember > 0, "Maximum mints per member must be greater than zero");
        uint256 dealId = clubs[_clubId].nextDealId++;

        // Initialize the Deal struct
        Deal storage newDeal = clubDeals[_clubId][dealId];
        newDeal.dealId = dealId;
        newDeal.maxSupply = _maxSupply;
        newDeal.remainingSupply = _maxSupply;
        newDeal.expiryDate = _expiryDate;
        newDeal.redeemedSupply = 0;
        newDeal.maxMintsPerMember = _maxMintPerMember;
        newDeal.metadataURI = _metadataURI;

        emit DealCreated(_clubId, dealId, _maxSupply, _expiryDate, _metadataURI);
        return dealId;
    }

    // Function to mint a deal NFT for a club member
    function mintDeal(uint256 _clubId, uint256 _dealId) external onlyClubMember(_clubId) {
        // Ensure the deal exists and is active
        Deal storage deal = clubDeals[_clubId][_dealId];
        require(deal.expiryDate > block.timestamp, "Deal has expired");
        require(deal.remainingSupply > 0, "Deal is out of stock");

        // Check if the member has reached their mint limit for this deal
        require(deal.mintsPerMember[msg.sender] < deal.maxMintsPerMember, "Mint limit reached for this deal");

        // Mint the NFT and send it to the member
        string memory metadataURI = deal.metadataURI;
        mintDealsNFT.mintNFT(msg.sender, _clubId, _dealId, metadataURI);

        // Update deal status
        deal.remainingSupply -= 1;
        deal.mintsPerMember[msg.sender] += 1;

    }

    /// @notice Confirm the redemption of a deal held by a member
    function confirmRedemption(uint256 _clubId, uint256 _dealId, uint256 tokenId) external nonReentrant onlyClubOwner(_clubId) {    

        // Ensure the deal exists and is active
        Deal storage deal = clubDeals[_clubId][_dealId];
        require(deal.expiryDate > block.timestamp, "Deal has expired");
        require(deal.remainingSupply > 0, "Deal is out of stock");
  
        // Interact with ClubDealNFT to confirm redemption
        mintDealsNFT.approveRedemption(tokenId);
        
        // Update deal status
        deal.redeemedSupply += 1;

        emit DealRedemptionConfirmed(_clubId, _dealId, msg.sender);
    }

    /// @notice Get all clubs a user is a member of
    /// @param _user The address of the user
    /// @return uint256[] An array of club IDs the user is a member of
    function getClubsForMember(address _user) public view returns (uint256[] memory) {
        uint256 clubCount = nextClubId;
        uint256[] memory result = new uint256[](clubCount);
        uint256 counter = 0;

        for (uint256 i = 0; i <= clubCount; i++) {
            if (clubs[i].members[_user]) {
                result[counter] = i;
                counter++;
            }
        }

        // Resize the array to remove empty elements
        uint256[] memory memberClubs = new uint256[](counter);
        for (uint256 j = 0; j < counter; j++) {
            memberClubs[j] = result[j];
        }

        return memberClubs;
    }

    //Admin Withdraw for collected club creation fees
    function withdrawFees(address _paymentTokenAddress, uint256 _amount) external onlyAdmin(msg.sender) {
        uint256 collectedAmount = collectedFeesByToken[_paymentTokenAddress];
        require(collectedAmount >= _amount, "Insufficient fees collected");

        IERC20 token = IERC20(_paymentTokenAddress);
        token.transfer(msg.sender, _amount);

        collectedFeesByToken[_paymentTokenAddress] -= _amount;
    }

    // Internal function to adjust fee based on token decimals
    function _adjustFeeForDecimals(address _tokenAddress, uint256 _amount) internal view returns (uint256) {
        IERC20Metadata token = IERC20Metadata(_tokenAddress);
        uint8 tokenDecimals = token.decimals();

        if (tokenDecimals == 6) {
            return _amount / 1e12; // Adjust 18-decimal amount to 6-decimal format
        } else if (tokenDecimals == 18) {
            return _amount; // No adjustment needed for 18-decimal tokens
        } else {
            revert("Unsupported token decimals");
        }
    }

    //// External Swapping

    /**
    * @notice Withdraw to swap tokens using a CEX/DEX for supplying to CreditFacility->JL.
    * @param tokenIn The address of the input token.
    * @param tokenOut The address of the output token.
    * @param to The address to receive the tokens.
    * @return amountOut The amount of tokens exiting registry.
    */
    function swapViaEX(address tokenIn, address tokenOut, address to) external nonReentrant onlyAdmin(msg.sender) returns (uint256 amountOut) {
        // Ensure there are funds available for swap
        require(splitForCreditManager[tokenIn] > 0, "No funds available for swap");

        // Amount available for swap
        amountOut = splitForCreditManager[tokenIn];

        // Perform the token transfer
        IERC20(tokenIn).transfer(to, amountOut);

        // Update accumulated balance
        splitForCreditManager[tokenIn] -= amountOut;

        emit SwappedViaEX(tokenIn, tokenOut, amountOut, to);

        return amountOut;

    }

    // Optionally Logs the result of a CEX swap operation for extended transparency
    function logOffChainSwapResult(string memory txnHash) external onlyAdmin(msg.sender) {
        emit txnExecuted(txnHash);
    }

}
