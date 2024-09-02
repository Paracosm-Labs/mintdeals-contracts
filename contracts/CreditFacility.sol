// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICErc20.sol";
import "./interfaces/IComptroller.sol";
import "./interfaces/IMerkleDistributor.sol";
import "./interfaces/IPriceOracle.sol";
import "./AdminAuth.sol";

/**
 * @title CreditFacility
 * @dev This contract provides functions to interact with JustLend, including managing assets, collateral, borrowing, repaying and yield claiming.
 */
contract CreditFacility is AdminAuth, ReentrancyGuard {
    // Struct to store cToken details
    struct CTokenInfo {
        ICErc20 cToken;
        address underlyingAsset;
        bool isStablecoin;
        IPriceOracle priceOracle;
    }

    // Struct to store user information for a specific cToken
    struct UserInfo {
        uint256 amountDeposited; // Amount deposited
        uint256 amountBorrowed; // Amount of stablecoin borrowed
        uint256 lastUpdateBlock; // Last block number when borrowing or accrual update occurred
    }

    // Contract addresses for different roles
    IComptroller public comptroller;
    IMerkleDistributor public merkleDistributor;

    mapping(address => CTokenInfo) public cTokens; // Mapping to store cToken information
    address[] public cTokenAddresses; // To keep track of all cToken addresses

    // Unified mapping for user information by cToken address
    mapping(address => mapping(address => UserInfo)) public userInfos;

    // Admin-configurable collateral factors
    uint public stablecoinCollateralFactor = 70; // Default is 70%
    uint public nonStablecoinCollateralFactor = 25; // Default is 25%

    // Storage for accumulated yield
    uint256 public yieldBalance;

    // Events
    event SupplyAsset(address indexed cTokenAddress, uint amount, address recipient);
    event RedeemedAsset(address indexed user, address indexed cTokenAddress, uint amount);
    event Repayment(address indexed borrower, address cTokenAddress, uint repaymentAmount);
    event Borrowed(address indexed borrower, address cTokenAddress, uint amount);

    /**
     * @param _comptrollerAddress Address of the Comptroller contract.
     * @param _merkleDistributorAddress Address of the Merkle Distributor contract.
     */
    constructor(address _comptrollerAddress, address _merkleDistributorAddress) {
        comptroller = IComptroller(_comptrollerAddress);
        merkleDistributor = IMerkleDistributor(_merkleDistributorAddress);
    }

    /**
     * @notice Add a new cToken contract to the system.
     * @param _cTokenAddress The address of the cToken contract.
     * @param _underlyingAsset The underlying asset address of the cToken.
     * @param _isStablecoin Boolean indicating whether the cToken is a stablecoin.
     * @param _priceOracle The address of the price oracle contract. Can be address(0) if not needed.
     */
    function addCToken(address _cTokenAddress, address _underlyingAsset, bool _isStablecoin, address _priceOracle) external onlyAdmin(msg.sender) {
        require(address(cTokens[_cTokenAddress].cToken) == address(0), "cToken already added");
        cTokens[_cTokenAddress] = CTokenInfo({
            cToken: ICErc20(_cTokenAddress),
            underlyingAsset: _underlyingAsset,
            isStablecoin: _isStablecoin,
            priceOracle: IPriceOracle(_priceOracle)
        });
        cTokenAddresses.push(_cTokenAddress);
    }

    /**
     * @notice Update the collateral factor.
     * @param newStablecoinFactor The new stablecoin collateral factor percentage (e.g., 70 for 70%).
     * @param newNonStablecoinFactor The new non-stablecoin collateral factor percentage (e.g., 25 for 25%).
     */
    function updateCollateralFactors(uint newStablecoinFactor, uint newNonStablecoinFactor) external onlyAdmin(msg.sender) {
        require(newStablecoinFactor > 0 && newStablecoinFactor <= 100, "Invalid stablecoin factor");
        require(newNonStablecoinFactor > 0 && newNonStablecoinFactor <= 100, "Invalid non-stablecoin factor");
        stablecoinCollateralFactor = newStablecoinFactor;
        nonStablecoinCollateralFactor = newNonStablecoinFactor;
    }

    /**
    * @notice Enter markets as collateral (add assets to liquidity calculation).
    * @param cTokensAddress The address of the cToken to add as collateral.
    */
    function enableAsCollateral(address cTokensAddress) external onlyAdmin(msg.sender) {
        uint result = comptroller.enterMarket(cTokensAddress);
        require(result == 0, "Failed to enter market as collateral");
    }


    /**
    * @notice Supply a specific amount of the underlying asset to JustLend and receive cTokens, 
    *         either for the sender or on behalf of another user.
    * @param cTokenAddress The address of the cToken contract to interact with.
    * @param amount The amount of the underlying asset to supply.
    * @param beneficiary The address of the user on whose behalf the asset is being supplied (optional).
    * @return Returns 0 on success.
    */
    function supplyAsset(address cTokenAddress, uint256 amount, address beneficiary) external nonReentrant returns (uint256) {
        address recipient = beneficiary != address(0) ? beneficiary : msg.sender;

        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];
        require(address(cTokenInfo.cToken) != address(0), "cToken not supported");

        IERC20 underlyingToken = IERC20(cTokenInfo.underlyingAsset);
        require(address(underlyingToken) != address(0), "Underlying asset not found");

        require(underlyingToken.transferFrom(msg.sender, address(this), amount), "Transfer from sender failed");

        require(underlyingToken.approve(address(cTokenInfo.cToken), amount), "Approval for cToken failed");

        require(cTokenInfo.cToken.mint(amount) == 0, "Minting cTokens failed");

        _accrueInterest(cTokenAddress, recipient);


        // Update stored balance
        userInfos[recipient][cTokenAddress].amountDeposited += amount;

        emit SupplyAsset(cTokenAddress, amount, recipient);
        return 0; // 0 = success

    }


    /**
    * @notice Redeem (withdraw) a specific amount of the underlying asset from the protocol.
    * @param cTokenAddress The address of the cToken contract to interact with.
    * @param amount The amount of the underlying asset to redeem.
    * @return Returns 0 on success.
    */
    function redeemAsset(address cTokenAddress, uint256 amount) external nonReentrant returns (uint256) {
        // Fetch the user's info and the cToken info
        UserInfo storage userInfo = userInfos[msg.sender][cTokenAddress];
        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];
        
        require(address(cTokenInfo.cToken) != address(0), "cToken not supported");
        
        _accrueInterest(cTokenAddress, msg.sender);

        // Ensure the user has enough deposited to redeem
        require(userInfo.amountDeposited >= amount, "Insufficient balance to redeem");

        // Calculate the total stablecoin borrows (across all assets)
        uint256 totalStablecoinBorrows = calculateTotalUserStablecoinBorrows(msg.sender);

        // Temporarily reduce the user's amountDeposited by the amount they wish to redeem
        userInfo.amountDeposited -= amount;

        // Calculate the new borrowing power after the redemption
        uint256 newBorrowingPower = this.calculateTotalBorrowingPower(msg.sender);

        // Revert the amountDeposited change if the user would become under-collateralized
        require(newBorrowingPower >= totalStablecoinBorrows, "Redemption would cause under-collateralization");
        
        // Perform the actual redemption from the cToken contract
        require(cTokenInfo.cToken.redeemUnderlying(amount) == 0, "Redemption failed");

        // Transfer to requester
        require(IERC20(cTokenInfo.underlyingAsset).transfer(msg.sender, amount), "Transfer failed");

        emit RedeemedAsset(msg.sender, cTokenAddress, amount);

        return 0; // 0 = success
    }

    /**
    * @notice Borrow a specific amount of the underlying asset from JustLend.
    * @param cTokenAddress The address of the cToken contract (must be a stablecoin).
    * @param amount The amount of the underlying asset to borrow.
    * @return Returns 0 on success.
    */
    function borrow(address cTokenAddress, uint256 amount) external nonReentrant returns (uint256) {
        // Fetch the stablecoin cToken info
        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];
        require(address(cTokenInfo.cToken) != address(0), "cToken not supported");
        require(cTokenInfo.isStablecoin, "Can only borrow stablecoins");

        UserInfo storage userInfo = userInfos[msg.sender][cTokenAddress];

        // Accrue interest if there was a previous borrow
        _accrueInterest(cTokenAddress, msg.sender);

        // Calculate user's total borrowing power based on their deposits
        uint256 totalBorrowingPower = this.calculateTotalBorrowingPower(msg.sender);

        // Calculate total stablecoin borrows by the user
        uint256 totalBorrowed = calculateTotalUserStablecoinBorrows(msg.sender);

        // Ensure the requested borrow amount does not exceed the maximum borrowable amount
        require(totalBorrowed + amount <= totalBorrowingPower, "Borrow exceeds allowable amount");

        // Perform the borrowing
        require(cTokenInfo.cToken.borrow(amount) == 0, "Borrowing from cToken failed"); // response 0 == success

        // Transfer to requester
        require(IERC20(cTokenInfo.underlyingAsset).transfer(msg.sender, amount), "Transfer failed");

        // Update the user's borrowed amount and last update block for this stablecoin
        userInfo.amountBorrowed += amount; // Only stablecoins are borrowed

        emit Borrowed(msg.sender, cTokenAddress, amount);
        
        return 0; // 0 = success
    }


    /**
    * @notice Repay a specific amount of the borrowed stablecoin.
    * @param cTokenAddress The address of the cToken contract (must be a stablecoin).
    * @param amount The amount of the borrowed asset to repay.
    * @return Returns 0 on success.
    */
    function repayBorrow(address cTokenAddress, uint256 amount, address beneficiary) external nonReentrant returns (uint256) {
        address recipient = beneficiary != address(0) ? beneficiary : msg.sender;
        // Fetch the stablecoin cToken info
        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];
        require(address(cTokenInfo.cToken) != address(0), "cToken not supported");
        require(cTokenInfo.isStablecoin, "Only stablecoin borrowings can be repaid");

        _accrueInterest(cTokenAddress, recipient);

        UserInfo storage userInfo = userInfos[recipient][cTokenAddress];

        // Ensure the user has enough borrowed balance to repay
        require(userInfo.amountBorrowed >= amount, "Repay amount exceeds borrowed balance");

        // Transfer to cTokenAddress
        require(IERC20(cTokenInfo.underlyingAsset).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Perform the repayment
        require(cTokenInfo.cToken.repayBorrow(amount) == 0, "Repayment failed"); // response 0 == success

        // Update the user's borrowed amount and last update block
        userInfo.amountBorrowed -= amount; // Reduce borrowed amount

        emit Repayment(recipient, cTokenAddress, amount);

        return 0; // 0 = success
    }

    // External function to call to accrue Interest
    function accrueInterest(address cTokenAddress, address user) external nonReentrant {
        _accrueInterest(cTokenAddress, user);
    }


    /**
    * @notice Updates the borrow record of the user by calculating accrued interest and updating state.
    * @param cTokenAddress The address of the cToken contract associated with the borrow.
    * @param user The address of the user whose borrow record is being updated.
    */
    function _accrueInterest(address cTokenAddress, address user) internal {
        // Fetch the cToken info to check if it's a stablecoin
        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];

        // Ensure that interest is accrued only for stablecoins
        if (!cTokenInfo.isStablecoin) {
            return; // Skip interest accrual for non-stablecoins
        }

        // Fetch user info for the relevant cToken
        UserInfo storage userInfo = userInfos[user][cTokenAddress];

        // If this is the first time accruing interest, set the lastUpdateBlock to the current block
        if (userInfo.lastUpdateBlock == 0) {
            userInfo.lastUpdateBlock = block.number;
            return;
        }

        // Get the borrowed amount for the stablecoin
        uint256 borrowedAmount = userInfo.amountBorrowed;

        // Ensure interest is only accrued if there is an outstanding borrowed amount and a lastUpdateBlock value above 0
        if (borrowedAmount == 0) {
            return; // No borrowing has occurred, so skip interest accrual
        }

        // Calculate the number of blocks that have elapsed since the last update
        uint256 blocksElapsed = block.number - userInfo.lastUpdateBlock;

        // Get the borrow rate per block from the cToken contract
        uint256 borrowRatePerBlock = cTokenInfo.cToken.borrowRatePerBlock();

        // Calculate accrued interest
        uint256 accruedInterest = (borrowedAmount * borrowRatePerBlock * blocksElapsed) / 1e18;

        // Update the total borrowed amount with accrued interest
        userInfo.amountBorrowed += accruedInterest;

        // Update the last update block to the current block
        userInfo.lastUpdateBlock = block.number;
    }


    /**
    * @notice Claim yield rewards from the Merkle Distributor.
    * @param merkleIndex The index in the Merkle tree for the claim.
    * @param index The index of the reward in the claim.
    * @param amount The amount of reward to claim.
    * @param merkleProof The Merkle proof for the claim.
    */
    function claimYield(uint256 merkleIndex, uint256 index, uint256 amount, bytes32[] calldata merkleProof) external onlyAdmin(msg.sender) {
        // Claim the yield from the Merkle Distributor
        merkleDistributor.claim(merkleIndex, index, amount, merkleProof);

        // Accumulate the claimed yield in the contract
        yieldBalance += amount;
    }

    /**
    * @notice Withdraw accumulated yield by the admin.
    * @param amount The amount of yield to withdraw.
    */
    function withdrawYield(address rewardToken, uint256 amount) external onlyAdmin(msg.sender) {
        require(amount <= yieldBalance, "Insufficient yield balance");

        // Transfer the yield to the admin
        IERC20(rewardToken).transfer(msg.sender, amount);

        // Update the yield balance
        yieldBalance -= amount;
    }



    // Views

    /**
    * @notice Calculate the total borrowing power of a specific user.
    * @param user The address of the user.
    * @return The total borrowing power of the user.
    */
    function calculateTotalBorrowingPower(address user) external view returns (uint256) {
        uint256 stablecoinDeposits = 0;
        uint256 nonStablecoinDeposits = 0;
        uint256 totalBorrowingPower = 0;

        // Loop through all cToken addresses to calculate total borrowing power
        for (uint256 i = 0; i < cTokenAddresses.length; i++) {
            address cTokenAddress = cTokenAddresses[i];
            CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];

            if (cTokenInfo.isStablecoin) {
                // Apply stablecoin collateral factor
                stablecoinDeposits = userInfos[user][cTokenAddress].amountDeposited;
                totalBorrowingPower += (stablecoinDeposits * stablecoinCollateralFactor) / 100;
            } else {
                // Get USD valuation of non-stablecoin and apply collateral factor
                nonStablecoinDeposits =  this.getUserReserveValuation(cTokenAddress, user);
                totalBorrowingPower += (nonStablecoinDeposits * nonStablecoinCollateralFactor) / 100;
            }
        }

        return totalBorrowingPower;
    }


    /**
    * @notice Calculate the total amount of stablecoins borrowed by a user.
    * @param user The address of the user whose borrows are to be calculated.
    * @return totalUserStablecoinBorrows The total stablecoin borrows of the user.
    */
    function calculateTotalUserStablecoinBorrows(address user) public view returns (uint256 totalUserStablecoinBorrows) {
        for (uint i = 0; i < cTokenAddresses.length; i++) {
            address cTokenAddress = cTokenAddresses[i];
            if (cTokens[cTokenAddress].isStablecoin) {
                totalUserStablecoinBorrows += userInfos[user][cTokenAddress].amountBorrowed;
            }
        }
        return totalUserStablecoinBorrows;
    }

    /**
    * @notice Calculate the total amount of stablecoins deposits by a user.
    * @param user The address of the user whose deposits are to be calculated.
    * @return totalStablecoinDeposits The total stablecoin deposits of the user.
    * @return nonStablecoinDeposits An array of the total non stablecoin deposits of the user.
    */
    function calculateTotalUserDeposits(address user) public view returns (uint256 totalStablecoinDeposits, uint256[] memory nonStablecoinDeposits) {
        uint256 nonStablecoinCount = 0;
        
        // First pass: count the number of non-stablecoins to size the array
        for (uint i = 0; i < cTokenAddresses.length; i++) {
            address cTokenAddress = cTokenAddresses[i];
            if (!cTokens[cTokenAddress].isStablecoin) {
                nonStablecoinCount++;
            }
        }
        
        // Initialize the array to store non-stablecoin deposits
        nonStablecoinDeposits = new uint256[](nonStablecoinCount);
        uint256 index = 0;
        
        // Second pass: calculate totals and fill the non-stablecoin array
        for (uint i = 0; i < cTokenAddresses.length; i++) {
            address cTokenAddress = cTokenAddresses[i];
            UserInfo storage userInfo = userInfos[user][cTokenAddress];
            
            if (cTokens[cTokenAddress].isStablecoin) {
                totalStablecoinDeposits += userInfo.amountDeposited;
            } else {
                nonStablecoinDeposits[index] = userInfo.amountDeposited;
                index++;
            }
        }
        
        return (totalStablecoinDeposits, nonStablecoinDeposits);
    }


    /**
    * @notice Gets the valuation of a user's non-stablecoin asset deposits by fetching the amount deposited and current price.
    * @param cTokenAddress The address of the cToken contract to interact with.
    * @param user The address of the user whose reserve valuation is being queried.
    * @return valuation The total reserve value of the non-stablecoin assets for the user, normalized to 18 decimals.
    */
    function getUserReserveValuation(address cTokenAddress, address user) public view returns (uint256 valuation) {
        CTokenInfo storage cTokenInfo = cTokens[cTokenAddress];
        UserInfo storage userInfo = userInfos[user][cTokenAddress];

        if (!cTokenInfo.isStablecoin) {
            require(address(cTokenInfo.priceOracle) != address(0), "Oracle not set for non-stablecoin");

            // Fetch the amount of underlying asset deposited by the user
            uint256 collateralAmount = userInfo.amountDeposited;

            // Fetch the latest price from the oracle
            int256 rawPrice = cTokenInfo.priceOracle.latestAnswer();
            require(rawPrice > 0, "Invalid oracle price");

            uint8 oraclePriceDecimals = cTokenInfo.priceOracle.decimals();
            uint8 tokenDecimals = IERC20Metadata(cTokenInfo.underlyingAsset).decimals();

            // Normalize the price to 18 decimals
            uint256 normalizedPrice = uint256(rawPrice) * (10 ** (18 - oraclePriceDecimals));

            // Normalize the collateral amount to 18 decimals
            uint256 normalizedCollateralAmount = collateralAmount * (10 ** (18 - tokenDecimals));

            // Calculate the valuation
            valuation = (normalizedCollateralAmount * normalizedPrice) / 1e18; // Result in 18 decimals

            return valuation;
        }
        return 0;
    }



    /**
    * @notice Get the cToken address associated with a specific underlying token.
    * @param underlying The address of the underlying token.
    * @return The address of the corresponding cToken.
    */
    function getCTokenAddress(address underlying) external view returns (address) {
        // Iterate through all cTokens to find the matching underlying asset
        for (uint i = 0; i < cTokenAddresses.length; i++) {
            address cTokenAddress = cTokenAddresses[i];
            if (cTokens[cTokenAddress].underlyingAsset == underlying) {
                return cTokenAddress;
            }
        }
        
        // If no matching cToken is found, revert
        revert("CToken does not exist for the given underlying asset");
    }

}