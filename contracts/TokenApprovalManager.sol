// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./AdminAuth.sol";

contract TokenApprovalManager is AdminAuth {
    // Function to set unlimited allowance for a token
    function setUnlimitedAllowance(address tokenAddress, address spender) external onlyAdmin(msg.sender) {
        IERC20 token = IERC20(tokenAddress);
        uint256 unlimitedAmount = type(uint256).max;
        require(token.approve(spender, unlimitedAmount), "Approval failed");
    }
}
