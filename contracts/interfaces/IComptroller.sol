// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IComptroller {
    function enterMarket(address cToken) external returns (uint);
    function enterMarkets(address[] memory cTokens) external returns (uint[] memory);
}
