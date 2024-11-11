// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; // Import Ownable

contract RegaliumToken is ERC20, Ownable { // Inherit from Ownable
    // Mapping to keep track of user balances in the game
    mapping(address => uint256) private inGameBalances;

    // Event emitted when tokens are withdrawn from the game
    event TokensWithdrawn(address indexed user, uint256 amount);

    // Event emitted when tokens are used for in-game purchases
    event InGamePurchase(address indexed user, uint256 amount);

    // Constructor to initialize the token name, symbol, and mint initial supply to the owner
    constructor() ERC20("Regalium", "RGLM") Ownable(msg.sender) {  
        // Initial mint to the owner (game developer)
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }

    // Function to transfer tokens from the contract to the user's wallet
    function withdrawTokens(uint256 amount) external {
        require(inGameBalances[msg.sender] >= amount, "Insufficient in-game balance");
        
        inGameBalances[msg.sender] -= amount;
        _transfer(address(this), msg.sender, amount);

        emit TokensWithdrawn(msg.sender, amount);
    }

    // Function to use tokens for in-game purchases
    function inGamePurchase(uint256 amount) external {
        require(balanceOf(msg.sender) >= amount, "Insufficient token balance");

        _transfer(msg.sender, address(this), amount);
        inGameBalances[msg.sender] += amount;

        emit InGamePurchase(msg.sender, amount);
    }

    // Function to check the in-game balance of a user
    function inGameBalance(address user) external view returns (uint256) {
        return inGameBalances[user];
    }
}
