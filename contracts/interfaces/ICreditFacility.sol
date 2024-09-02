// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./ICErc20.sol";
import "./IComptroller.sol";
import "./IMerkleDistributor.sol";
import "./ISunRouter.sol";

/**
 * @title ICreditFacility
 * @dev This interface defines the functions for interacting with a credit facility contract.
 */
interface ICreditFacility {

    // Functions for the interface

    /**
     * @notice Supply a specific amount of the underlying asset to JustLend and receive cTokens.
     * @param cTokenAddress The address of the cToken contract to interact with.
     * @param amount The amount of the underlying asset to supply.
     * @param beneficiary The address of the user on whose behalf the asset is being supplied (optional).
     */
    function supplyAsset(address cTokenAddress, uint amount, address beneficiary) external returns (uint256);

    /**
     * @notice Redeem a specific amount of the underlying asset by burning the corresponding cTokens.
     * @param cTokenAddress The address of the cToken contract to interact with.
     * @param amount The amount of the underlying asset to redeem.
     */
    function redeemAsset(address cTokenAddress, uint amount) external returns (uint256);

    /**
     * @notice Borrow a specified amount of the underlying asset, only if it is a stablecoin.
     * @param cTokenAddress The address of the cToken contract to interact with.
     * @param amount The amount of the underlying asset to borrow.
     * @return uint Returns 0 on success.
     */
    function borrow(address cTokenAddress, uint amount) external returns(uint256);

    /**
     * @notice Repay a borrower's debt using their own funds or on behalf of another user.
     * @param cTokenAddress The address of the cToken contract to interact with.
     * @param amount The amount to repay.
     * @param account The address of the account being repaid (optional).
     */
    function repayBorrow(address cTokenAddress, uint amount, address account) external returns (uint256);

       
    /**
     * @notice External function to call to accrue Interest
     * It should be called periodically by the protocol in order to maintain up-to-date interest rates.
     * @param cTokenAddress The address of the cToken contract to interact with.
     * @param user The address of the user whose interest is being accrued.
     */
    function accrueInterest(address cTokenAddress, address user) external;
    
    /**
    * @notice Gets the amount of underlying non-stablecoin asset in the facility and its price to determine the total reserve value.
    * @param cTokenAddress The address of the cToken contract to interact with.
    * @param account The address of the user whose reserve valuation is being queried.
    * @return The total reserve value of the non-stablecoin assets for the user.
    */
    function getUserReserveValuation(address cTokenAddress, address account) external view returns (uint256);

    /**
     * @notice Returns a snapshot of the user's current debt including accrued interest.
     * @param cTokenAddress The address of the cToken contract associated with the borrow.
     * @param user The address of the user whose debt snapshot is to be retrieved.
     * @return totalDebt The total debt of the user including accrued interest.
     */
    function getUserDebtSnapshot(address cTokenAddress, address user) external view returns (uint256 totalDebt);

    /**
     * @notice Get the cToken address associated with a specific underlying token.
     * @param underlying The address of the underlying token.
     * @return The address of the corresponding cToken.
     */
    function getCTokenAddress(address underlying) external view returns (address);

    /**
    * @notice Calculate the total borrowing power of a specific user.
    * @param user The address of the user.
    * @return The total borrowing power of the user.
    */
    function calculateTotalBorrowingPower(address user) external view returns (uint256);

    /**
     * @notice Calculate the total deposits of a specific user across all stablecoins.
     * @param user The address of the user whose deposits are to be calculated.
     * @return totalUserStablecoinDeposits The total stablecoin deposits of the user.
     */
    function calculateTotalUserStablecoinDeposits(address user) external view returns (uint256 totalUserStablecoinDeposits);

    /**
     * @notice Calculate the total borrows of a specific user across all stablecoins, including accrued interest.
     * @param user The address of the user whose borrows are to be calculated.
     * @return totalUserStablecoinBorrows The total stablecoin borrows of the user.
     */
    function calculateTotalUserStablecoinBorrows(address user) external view returns (uint256 totalUserStablecoinBorrows);

}
