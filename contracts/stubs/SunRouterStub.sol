// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// // Stub contract implementing ISunRouter interface for testing
// contract SunRouterStub {

//     // Struct for SwapData
//     struct SwapData {
//         uint256 amountIn;
//         uint256 amountOutMin;
//         address to;
//         uint256 deadline;
//     }

//     // Mock implementation of swapExactInput function
//     function swapExactInput(
//         address[] calldata path,
//         string[] calldata poolVersion,
//         uint256[] calldata versionLen,
//         uint24[] calldata fees,
//         SwapData calldata data
//     ) external pure returns (uint256[] memory amountsOut) {
//         // For testing purposes, return mock data
//         uint256 length = path.length;
//         amountsOut = new uint256[](length);

//         for (uint i = 0; i < length; i++) {
//             amountsOut[i] = data.amountIn / (i + 1); // Mock calculation
//         }
        
//         return amountsOut;
//     }
// }

