// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract CErc20Stub {
    mapping(address => uint256) private balances;
    mapping(address => uint256) private borrowBalances;
    uint256 private exchangeRate = 101157211754378640359062362;
    uint256 private borrowRate = 1e16; // 1% per block
    uint256 private supplyRate = 5e15; // 0.5% per block

    function mint(uint mintAmount) external returns (uint) {
        balances[msg.sender] += mintAmount;
        return 0; // Success
    }

    function redeem(uint redeemTokens) external returns (uint) {
        require(balances[msg.sender] >= redeemTokens, "Insufficient balance");
        balances[msg.sender] -= redeemTokens;
        return 0; // Success
    }

    function redeemUnderlying(uint redeemAmount) external returns (uint) {
        uint256 tokensToRedeem = (redeemAmount * 1e18) / exchangeRate;
        require(balances[msg.sender] >= tokensToRedeem, "Insufficient balance");
        balances[msg.sender] -= tokensToRedeem;
        return 0; // Success
    }

    function borrow(uint borrowAmount) external returns (uint) {
        borrowBalances[msg.sender] += borrowAmount;
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

    function balanceOf(address owner) external view returns (uint) {
        return balances[owner];
    }

    function balanceOfUnderlying(address owner) external view returns (uint) {
        return (balances[owner] * exchangeRate) / 1e8;
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