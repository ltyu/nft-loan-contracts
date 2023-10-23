// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableToken is ERC20{
    constructor() ERC20("USDC", "USDC") {
        _mint(msg.sender, 1000 ether);
    }

    function mint(address receiver, uint256 amount) external {
        _mint(receiver, amount);
    }
}