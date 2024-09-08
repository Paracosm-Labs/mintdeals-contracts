// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CErc20Stub is ERC20 {
    IERC20 underlyingAsset;

    mapping(address => uint256) private balances;
    mapping(address => uint256) private borrowBalances;
    uint256 private exchangeRate = 101157211754378640359062362;
    uint256 private borrowRate = 1e16; // 1% per block
    uint256 private supplyRate = 5e15; // 0.5% per block

    constructor(
        address _underlyingAssetAddress,
        string memory _name,
        string memory _symbol
    ) ERC20(_name, _symbol) {
        underlyingAsset = IERC20(_underlyingAssetAddress);
    }

    // Override the decimals function to return 8, like Bitcoin
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function mint(uint256 mintAmount) external returns (uint256) {
        underlyingAsset.transferFrom(msg.sender, address(this), mintAmount);
        uint256 tokens = mintAmount * exchangeRate;
        _mint(msg.sender, tokens);
        return 0;
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeem(uint256 redeemTokens) external returns (uint256) {
        _burn(msg.sender, redeemTokens);
        uint256 amount = redeemTokens / exchangeRate;
        underlyingAsset.transfer(msg.sender, amount);
        return 0;
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * @return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function redeemUnderlying(uint256 redeemAmount) external returns (uint256) {
        uint256 tokens = redeemAmount * exchangeRate;
        _burn(msg.sender, tokens);
        underlyingAsset.transfer(msg.sender, redeemAmount);
        return 0;
    }

    function borrow(uint borrowAmount) external returns (uint) {
        // Check if contract has enough underlying asset to lend
        require(underlyingAsset.balanceOf(address(this)) >= borrowAmount, "Insufficient underlying asset in contract");
        
        borrowBalances[msg.sender] += borrowAmount;
        // Transfer the borrowed amount to the borrower
        underlyingAsset.transfer(msg.sender, borrowAmount);
        return 0; // Success
    }

    function repayBorrow(uint repayAmount) external returns (uint) {
        require(borrowBalances[msg.sender] >= repayAmount, "Insufficient borrow balance");
        borrowBalances[msg.sender] -= repayAmount;
        return 0; // Success
    }

    function borrowRatePerBlock() external view returns (uint) {
        return borrowRate;
    }

    function supplyRatePerBlock() external view returns (uint) {
        return supplyRate;
    }

    /**
     * @notice Get the underlying balance of the `owner`
     * @dev This also accrues interest in a transaction
     * @param owner The address of the account to query
     * @return The amount of underlying owned by `owner`
     */
    function balanceOfUnderlying(address owner) external view returns (uint256) {
        uint256 balanceTokens = balanceOf(owner);
        uint256 balance = balanceTokens / exchangeRate;
        return balance;
    }

    function borrowBalanceCurrent(address account) external view returns (uint) {
        return borrowBalances[account];
    }

    function getAccountSnapshot(address account) external view returns (uint, uint, uint, uint) {
        return (0, balances[account], borrowBalances[account], exchangeRate);
    }

    function exchangeRateCurrent() external view returns (uint) {
        return exchangeRate;
    }

    // Additional functions for testing purposes

    function setBorrowRate(uint256 newRate) external {
        borrowRate = newRate;
    }

    function setSupplyRate(uint256 newRate) external {
        supplyRate = newRate;
    }

    function setExchangeRate(uint256 newRate) external {
        exchangeRate = newRate;
    }
}