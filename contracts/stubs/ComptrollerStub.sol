// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ComptrollerStub {
    mapping(address => bool) private enteredMarkets;

    function enterMarket(address cTokens) external returns (uint) {
            enteredMarkets[cTokens] = true;
        return 0;// Assuming success
    }

    // Additional functions for testing purposes

    function isEnteredMarket(address cToken) external view returns (bool) {
        return enteredMarkets[cToken];
    }
}
