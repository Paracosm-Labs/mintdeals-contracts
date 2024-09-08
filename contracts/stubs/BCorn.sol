// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BCorn is ERC20 {
    constructor() ERC20("NBCorn", "NBCORN") {}

    // Override the decimals function to return 8, like Bitcoin
    function decimals() public view virtual override returns (uint8) {
        return 8;
    }

    function mint(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }
}
