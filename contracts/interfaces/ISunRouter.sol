// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISunRouter {
    /**
     * @dev Exchange function for converting TRX to Token in a specified path.
     * @param path A specified exchange path from TRX to token.
     * @param poolVersion List of pool where tokens in path belongs to.
     * @param versionLen List of token num in each pool.
     * @param fees List of fees for each pool in the path.
     * @param data Encoded swap information.
     * @return amountsOut Array of output amounts for each step in the path.
     */
    function swapExactInput(
        address[] calldata path,
        string[] calldata poolVersion,
        uint256[] calldata versionLen,
        uint24[] calldata fees,
        SwapData calldata data
    ) external returns (uint256[] memory amountsOut);
}

struct SwapData {
    uint256 amountIn;       // Amount of input tokens
    uint256 amountOutMin;   // Minimum amount of output tokens to accept
    address to;             // Recipient address
    uint256 deadline;       // Timestamp after which the swap will no longer be valid
}
