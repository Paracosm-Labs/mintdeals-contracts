// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/ICErc20.sol";
import "./AdminAuth.sol";
import "./interfaces/ICreditFacility.sol";

contract CreditManager is AdminAuth, ReentrancyGuard {
    // Constants
    uint256 constant MAX_SCORE = 850; // Maximum possible credit score mirroring FICO max score
    uint256 constant BASELINE_SCORE = 500; // Basline score users start with
    
    // Struct for storing credit info
    struct CreditInfo {
        uint256 creditScore;         // User's credit score
        uint256 creditBalanceUsed;   // Amount already borrowed by the user
        uint256 lastUpdateBlock;     // The last block when interest was accrued
        uint256 lastRepaymentBlock;  // Block number of the last repayment
        uint256 boostFactor;         // Multiplier for user's borrowing capacity (default is 1)
    }

    // Mapping from user address to their CreditInfo
    mapping(address => CreditInfo) public userCredits;

    // Borrowing multiplier used to determine max borrowable in basis point. Eg. 20000 Represents 200% or x2.
    uint256 public borrowingMultiplierBP = 20000;

    // Interest delta per block as a percentage
    uint256 public interestDeltaPB = 420; // Example: 420 means the rate is scaled by 4.2

    // Admin-configurable global maximum credit limit valued in USD
    uint256 public globalMaxCreditLimit = 5000 * 10**18; // eg $5000

    // Admin-configuratble global credit factor - default 20%
    uint256 public globalCreditFactor = 20;

    // Total credit limit allocated
    uint256 public totalCreditUsed;

    // Credit Score steps for borrow+repay
    uint256 public borrowScoreStep;
    uint256 public repayScoreStep;

    //threshold of blocks passed since last repayment. default 864000 ~30 days
    uint256 public blocksPassedThreshold = 864000;

    // Stores fees collected from repayments
    uint256 public repaymentFees;

    // Reference to the CreditFacility contract
    ICreditFacility public creditFacility;

    constructor(address _creditFacility) {
        creditFacility = ICreditFacility(_creditFacility);
    }

    // Event declarations
    event CreditScoreUpdated(address indexed user, uint256 newScore);
    event Supplied(address tokenAddress, uint256 amount);
    event Withdrawn(address user, address tokenAddress, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event LoanRepayment(address indexed user, uint256 amount);
    event AdminRepayment(address tokenAddress, uint256 amount);
    event FeesWithdrawn(address to, uint256 amount);

    // Set the interest delta
    function setInterestDeltaPB(uint256 _delta) external onlyAdmin(msg.sender) {
        interestDeltaPB = _delta;
    }

    // Set or update the maximum global credit limit
    function setGlobalMaxCreditLimit(uint256 newLimit) external onlyAdmin(msg.sender) {
        globalMaxCreditLimit = newLimit;
    }

    // Set or update borrowing multiplier basis points used to determine max borrowable with credit score
    function setBorrowingMultiplierBP(uint256 newMultiplier) external onlyAdmin(msg.sender) {
        borrowingMultiplierBP = newMultiplier;
    }

    // Function to set score steps used for increasing/decreasing credit score
    function setScoreSteps(uint256 _borrowScoreStep, uint256 _repayScoreStep) external onlyAdmin(msg.sender) {
        borrowScoreStep = _borrowScoreStep;
        repayScoreStep = _repayScoreStep;
    }

   // Function to set threshold of blocks passed. Used in credit scoring
    function setBlocksPassedThreshold(uint256 _blocksPassedThreshold) external onlyAdmin(msg.sender) {
        blocksPassedThreshold = _blocksPassedThreshold;
    }

    // Initialise credit info for a user. Everyone starts with BASELINE_SCORE.
    function initializeCreditInfo(address user) internal {
        userCredits[user].creditScore = BASELINE_SCORE;
        userCredits[user].creditBalanceUsed = 0;
        userCredits[user].boostFactor = 1;
    }

    // Register User within Credit Manager
    function registerUser(address user) external onlyAdmin(msg.sender) {
        // Check if the user is already registered
        if (userCredits[user].creditScore != 0) {
            return; // User is already registered, so exit the function
        }

        // If not registered, proceed to initialize the user's credit info
        initializeCreditInfo(user);
    }

    /** 
     * @notice This function allows the contract to supply assets to the credit facility. 
     * It approves the specified amount of tokens for use by the CreditFacility contract and then supplies the asset using the CreditFacility's `supplyAsset` method.
     * @dev The function is marked as nonReentrant to prevent re-entrancy attacks. 
     * @param tokenAddress The address of the token to be supplied.
     * @param amount The amount of tokens to be supplied.
     */ 
    function supply(address tokenAddress, uint256 amount) external nonReentrant { 
        address cTokenAddress = creditFacility.getCTokenAddress(tokenAddress);
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount), "Transfer failed");

        // Get the current allowance
        uint256 currentAllowance = IERC20(tokenAddress).allowance(address(this), address(creditFacility));

        // Check if the allowance is less than or equal to the amount
        if (currentAllowance <= amount) {
            // Approve unlimited
            require(IERC20(tokenAddress).approve(address(creditFacility), type(uint256).max), "Approval for creditFacility failed");
        }

        creditFacility.supplyAsset(cTokenAddress, amount, address(this));
        emit Supplied(tokenAddress, amount); 
    }
       
    /** 
     * @notice This function allows an admin to withdraw assets from the credit facility. 
     * It approves the specified amount of tokens and then uses the CreditFacility's `redeemAsset` method to redeem these assets.
     * The function is marked as nonReentrant to prevent re-entrancy attacks. 
     * @dev Only the admin can call this function.
     * @param tokenAddress The address of the token to be withdrawn.
     * @param amount The amount of tokens to be withdrawn.
     */
    function withdraw(address tokenAddress, uint256 amount) external onlyAdmin(msg.sender) nonReentrant { 
        address cTokenAddress = creditFacility.getCTokenAddress(tokenAddress);
        creditFacility.redeemAsset(cTokenAddress, amount);
        IERC20(tokenAddress).transfer(msg.sender, amount);
        emit Withdrawn(msg.sender, tokenAddress, amount);
    }  

    /** 
    * @notice This function allows a user to borrow assets from the credit facility.
    * It approves the specified amount of tokens for use by the CreditFacility contract and then borrows the asset using the CreditFacility's `borrow` method.
    * The function is marked as nonReentrant to prevent re-entrancy attacks. 
    * @dev The borrowed amount should not exceed the user's credit limit or the global maximum credit limit.
    * @param tokenAddress The address of the token to be borrowed.
    * @param amount The amount of tokens to be borrowed.
    */
    function borrow(address tokenAddress, uint256 amount) external nonReentrant {
        address cTokenAddress = creditFacility.getCTokenAddress(tokenAddress);
        CreditInfo storage creditInfo = userCredits[msg.sender];

        // Accrue interest on the user's outstanding balance before borrowing
        _accrueInterest(cTokenAddress, msg.sender);

        // Calculate the user's current borrowing capacity based on their credit score
        uint256 maxBorrowable = calculateBorrowingCapacity(msg.sender);

        // Ensure the borrow request adheres to the user's borrowing capacity and global limits
        require(amount + creditInfo.creditBalanceUsed <= maxBorrowable, "Borrow amount exceeds your borrowing capacity");
        require(amount + totalCreditUsed <= globalMaxCreditLimit, "Global credit limit exceeded");

        // Execute the borrow action in CreditFacility
        creditFacility.borrow(cTokenAddress, amount);

        // Transfer the borrowed amount to the user
        IERC20(tokenAddress).transfer(msg.sender, amount);

        // Update the user's borrowed balance and total credit used in the accrueInterest function
        creditInfo.creditBalanceUsed += amount; // Just update the borrowed amount
        totalCreditUsed += amount; // Update the total credit used
        
        // Recalculate the user's credit score after borrowing
        _setCreditScore(msg.sender, borrowScoreStep, false);

        emit Borrowed(msg.sender, amount);
    }


    /**
    * @notice This function allows a user to repay assets to the credit facility.
    * It transfers the specified amount of tokens from the user's address to this contract, 
    * calculates an interest fee based on the repayment amount and interest rate,
    * and uses the CreditFacility's `repayBorrow` method to handle the repayment.
    * The function is marked as nonReentrant to prevent re-entrancy attacks.
    * @param tokenAddress The address of the token to be repaid.
    * @param repaymentAmount The amount of tokens to be repaid.
    */
    function repay(address tokenAddress, uint256 repaymentAmount) external nonReentrant {
        address cTokenAddress = creditFacility.getCTokenAddress(tokenAddress);
        CreditInfo storage creditInfo = userCredits[msg.sender];

        // Accrue interest on the user's outstanding balance before repayment
        _accrueInterest(cTokenAddress, msg.sender);

        // Calculate the effective repayment amount
        uint256 outstandingBalance = creditInfo.creditBalanceUsed;

        require(repaymentAmount > 0, "Repayment amount must be greater than zero");
        require(repaymentAmount <= outstandingBalance, "Repayment amount exceeds outstanding balance");

        // Transfer the repayment amount from the user to this contract
        require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), repaymentAmount), "Transfer failed");

        // Calculate the deltaPB portion of the repayment
        uint256 deltaPBPortion = (repaymentAmount * interestDeltaPB) / 10000;

        // Ensure deltaPBPortion does not exceed repaymentAmount
        deltaPBPortion = deltaPBPortion > repaymentAmount ? repaymentAmount : deltaPBPortion;

        // Subtract the deltaPB portion from the repayment amount
        uint256 netRepaymentAmount = repaymentAmount - deltaPBPortion;

        // Approve the net repayment amount for the credit facility
        // To optimize txn cost, spend pre-approval is handled in supply function

        // Forward the net repayment amount to the credit facility
        creditFacility.repayBorrow(cTokenAddress, netRepaymentAmount, address(this));

        // Update the user's credit balance used and total credit used
        creditInfo.creditBalanceUsed -= repaymentAmount;
        totalCreditUsed -= repaymentAmount;

        // Store the deltaBP portion in the repaymentFees variable
        repaymentFees += deltaPBPortion;

        // Recalculate the user's credit score after repayment
        _setCreditScore(msg.sender, repayScoreStep, true);

        emit LoanRepayment(msg.sender, repaymentAmount);
    }

    /** 
     * @notice This function allows an admin to make a repayment using repayment fees.
     * It transfers the specified amount of tokens from this contract's address to the CreditFacility contract, deducts it from `repaymentFees`, and then uses the CreditFacility's `repayBorrow` method to handle the repayment.
     * The function is marked as nonReentrant to prevent re-entrancy attacks. 
     * @dev Only the admin can call this function.
     * @param tokenAddress The address of the token to be repaid.
     * @param amount The amount of tokens to be repaid.
     */
    function repayWithFees(address tokenAddress, uint256 amount) external onlyAdmin(msg.sender) nonReentrant {
        require(amount <= repaymentFees, "Insufficient repayment fees available");

        // Reduce repayment fees before repayment
        repaymentFees -= amount;

        // Approve the amount for the credit facility
        // To optimize txn cost, spend pre-approval is handled in supply function

        address cTokenAddress = creditFacility.getCTokenAddress(tokenAddress);

        // Forward the repayment fees to the credit facility to repay account
        creditFacility.repayBorrow(cTokenAddress, amount, address(this));

        emit AdminRepayment(cTokenAddress, amount);
    }

    // Function for admin to withdraw fees
    function withdrawFees(address tokenAddress, uint256 amount, address to) external onlyAdmin(msg.sender) nonReentrant {
        // Ensure the requested amount does not exceed the repayment fees available
        require(amount <= repaymentFees, "Insufficient repayment fees available");

        // Deduct the amount from repaymentFees
        repaymentFees -= amount;

        // Transfer the amount to the admin address
        IERC20(tokenAddress).transfer(to, amount);

        emit FeesWithdrawn(to, amount);
    }
    
    /** 
     * @notice This function allows an admin to update the global maximum credit limit based on the valuation of non-stablecoin assets.
     * It calls the CreditFacility's getUserReserveValuation method to retrieve the valuation for a specified cToken address, and then updates the `maxCreditLimit` variable accordingly. 
     * The new global maximum credit limit is calculated as a percentage of the non-stablecoin valuation by the `globalCreditFactor` (default 20%).
     * @dev Only the admin can call this function.
     * @param cTokenAddress The address of the cToken representing the asset to be valued.
     * @return Returns the new global maximum credit limit.
     */
    function updateGlobalMaxCreditLimit(address cTokenAddress) external onlyAdmin(msg.sender) returns(uint256) {
        // Call to CreditFacility to get the valuation of non-stablecoin assets for this contract
        uint256 nonStablecoinValuation = creditFacility.getUserReserveValuation(cTokenAddress, address(this));

        // Update the global maximum credit limit based on this valuation
        globalMaxCreditLimit = (nonStablecoinValuation * globalCreditFactor) / 100;
        return globalMaxCreditLimit;
    }
       
    /** 
     * @notice This function allows an admin to set or decrease the user's credit score. The new score should not exceed MAX_SCORE and should be non-negative.
     * If the `increase` parameter is true, the user's current credit score will increase by the provided `scoreStep`; otherwise, it will decrease by that amount.
     * Only the admin can call this function. The event CreditScoreUpdated will be emitted upon successful execution of this function.
     * @dev This function should only be used for administrative purposes and is subject to strict review before usage.
     * @param user Address of the user whose credit score is being updated.
     * @param scoreStep The amount by which to increase or decrease the user's credit score.
     * @param increase A boolean value indicating whether to increase (true) or decrease (false) the user's credit score.
     * @param newBoostFactor Optional new boost factor for the user (set to 0 to keep the current boost factor).
     */
    function setCreditScore(address user, uint256 scoreStep, bool increase, uint256 newBoostFactor) external onlyAdmin(msg.sender) {
        _setCreditScore(user, scoreStep, increase);
        if (newBoostFactor > 0) {
            userCredits[user].boostFactor = newBoostFactor;
        }
    }

       
     // Internal function to adjust the credit score
    function _setCreditScore(address user, uint256 scoreStep, bool increase) internal {
        CreditInfo storage creditInfo = userCredits[user];
        
        // Calculate time elapsed since last repayment
        uint256 blocksElapsed = block.number - creditInfo.lastRepaymentBlock;

        // Optionally, adjust the scoreStep based on the time elapsed
        if (blocksElapsed > blocksPassedThreshold) {
            // Decrease scoreStep as time goes on to penalize inactivity
            scoreStep = _adjustScoreStepForTime(scoreStep, blocksElapsed);
        }
        
        if (increase) {
            // Increase score but not beyond MAX_SCORE
            if (creditInfo.creditScore + scoreStep > MAX_SCORE) {
                creditInfo.creditScore = MAX_SCORE;
            } else {
                creditInfo.creditScore += scoreStep;
            }
        } else {
            // Decrease score but not below 50% of BASELINE_SCORE
            if (creditInfo.creditScore >= scoreStep) {
                creditInfo.creditScore -= scoreStep;
            } else {
                creditInfo.creditScore = BASELINE_SCORE / 2;
            }
        }

        // Update the last repayment block if this operation is related to repayment
        if (increase) {
            creditInfo.lastRepaymentBlock = block.number;
        }
        
        emit CreditScoreUpdated(user, creditInfo.creditScore);
    }

    // Adjusts score step based on time. The longer the time elapsed, the smaller the scoreStep
    function _adjustScoreStepForTime(uint256 scoreStep, uint256 blocksElapsed) internal view returns (uint256) {
        if (blocksElapsed < blocksPassedThreshold + (blocksPassedThreshold / 3)) {
            return scoreStep; // No change if within grace period
        } else if (blocksElapsed < blocksPassedThreshold * 2) {
            return scoreStep / 2; // Half the effect if moderately overdue
        } else {
            return scoreStep / 4; // Quarter the effect if significantly overdue
        }
    }
    
    /**
     * @notice This function is responsible for calculating and updating the interest accrued by a user based on their credit score.
     * It does this by first checking if it's the user's first time calling `accrueInterest`, in which case it sets the lastUpdateBlock to the current block number. 
     * If not, it calculates the number of blocks elapsed since the last update and uses these along with the borrow rate per block from the cToken contract to calculate the interest accrued.
     * The function then applies any changes due to the `interestDeltaBP` variable (if any) before updating the user's credit balance with the accrued interest, and finally updates the lastUpdateBlock to the current block number. 
     * @param cTokenAddress The address of the cToken representing the asset on which interest is being accrued.
     * @param user The address of the user for whom we want to calculate and update the interest accrued.
     */
    function _accrueInterest(address cTokenAddress, address user) internal {
        CreditInfo storage creditInfo = userCredits[user];
        
        // If this is the first time accruing interest, set the lastUpdateBlock to the current block
        if (creditInfo.lastUpdateBlock == 0) {
            creditInfo.lastUpdateBlock = block.number;
            return;
        }

        // Calculate the number of blocks since the last update
        uint256 blocksElapsed = block.number - creditInfo.lastUpdateBlock;
        if (blocksElapsed == 0) return;

        // Get the borrow rate per block from the cToken
        uint256 borrowRatePerBlock = ICErc20(cTokenAddress).borrowRatePerBlock();

        // Apply the interestDeltaPB to the borrow rate per block
        uint256 adjustedBorrowRatePerBlock = borrowRatePerBlock * (10000 + interestDeltaPB) / 10000;

        // Calculate interest accrued
        uint256 interestAccrued = (creditInfo.creditBalanceUsed * adjustedBorrowRatePerBlock * blocksElapsed) / 1e18;

        // Update the user's credit balance with the accrued interest
        creditInfo.creditBalanceUsed += interestAccrued;

        // Update the lastUpdateBlock to the current block
        creditInfo.lastUpdateBlock = block.number;
    }


    /**
     * @notice Internal function to calculate the borrowing capacity of a user based on their credit score and boost factor.
     * @param user Address of the user whose borrowing capacity is being calculated.
     * @return Returns the maximum amount that can be borrowed based on the user's credit score, borrowing multiplier, and boost factor.
     */
    function calculateBorrowingCapacity(address user) internal view returns (uint256) {
        CreditInfo storage creditInfo = userCredits[user];
        return (creditInfo.creditScore * borrowingMultiplierBP * creditInfo.boostFactor * 1e18) / 10000;
    }


    // Views

    /**
     * @notice Retrieve the credit score, credit balance used, and borrowing capacity of a user.
     * @param user Address of the user.
     * @return score The user's current credit score.
     * @return creditBalanceUsed The user's current credit balance used.
     * @return borrowingCapacity The maximum amount that can be borrowed by the user based on their credit score and boost factor.
     */
    function getCreditInfo(address user) external view returns (uint256 score, uint256 creditBalanceUsed, uint256 borrowingCapacity) {
        CreditInfo storage creditInfo = userCredits[user];
        score = creditInfo.creditScore;
        creditBalanceUsed = creditInfo.creditBalanceUsed;
        borrowingCapacity = calculateBorrowingCapacity(user);
        return (score, creditBalanceUsed, borrowingCapacity);
    }
}
