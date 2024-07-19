// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RegaliumToken is ERC20, Ownable {
    uint256 public presaleEndTime;
    uint256 public presaleRate; // RGLM per MATIC
    uint256 public buybackRate; // RGLM per MATIC (scaled by 10 to avoid decimals)
    bool public buybackEnabled;

    event TokensBought(address indexed buyer, uint256 amount);
    event TokensSold(address indexed seller, uint256 amount);

    constructor() ERC20("Regalium", "RGLM") Ownable(msg.sender) {
        presaleEndTime = 1767120000; // 30-10-2025
        presaleRate = 2 * 10; // Using 20 to represent 2 RGLM per MATIC (scaled by 10)
        buybackRate = 1.5 * 10; // Using 15 to represent 1.5 RGLM per MATIC (scaled by 10)
        buybackEnabled = false;
    }

    // Presale function: Buy tokens with MATIC
    receive() external payable {
        require(block.timestamp < presaleEndTime, "Presale has ended");
        require(msg.value > 0, "Send MATIC to buy tokens");

        uint256 tokenAmount = (msg.value * presaleRate) / 10;
        _mint(msg.sender, tokenAmount);

        emit TokensBought(msg.sender, tokenAmount);
    }

    // Enable or disable buyback
    function setBuybackEnabled(bool _enabled) external onlyOwner {
        buybackEnabled = _enabled;
    }

    // Allow users to sell tokens back to the contract
    function sellTokens(uint256 tokenAmount) external {
        require(buybackEnabled, "Buyback is not enabled");
        require(tokenAmount > 0, "Specify an amount of tokens to sell");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens");

        uint256 maticAmount = (tokenAmount * 10) / buybackRate;
        require(address(this).balance >= maticAmount, "Not enough MATIC in contract");

        _burn(msg.sender, tokenAmount);
        payable(msg.sender).transfer(maticAmount);

        emit TokensSold(msg.sender, tokenAmount);
    }

    // Withdraw MATIC from contract (only owner)
    function withdrawMATIC(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Not enough MATIC in contract");
        payable(owner()).transfer(amount);
    }

    // Withdraw any ERC20 tokens from contract (only owner)
    function withdrawTokens(address tokenAddress, uint256 amount) external onlyOwner {
        IERC20(tokenAddress).transfer(owner(), amount);
    }
}
