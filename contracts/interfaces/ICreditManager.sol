// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

/**
 * @title ICreditManager
 * @dev This interface defines the functions for interacting with a credit manager contract.
 */
interface ICreditManager {

function registerUser(address user) external;
function supply(address tokenAddress, uint256 amount) external;
function borrow(address tokenAddress, uint256 amount) external;
function repay(address tokenAddress, uint256 repaymentAmount) external;



}