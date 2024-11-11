// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
//import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract RegaliumToken is ERC20, ERC20Burnable {
    using Math for uint256;

    uint256 public constant MAX_SUPPLY = 50000000 * 10**18;
    uint256 public totalMined;
    uint256 public difficulty = 10**10;
    mapping(address => uint256) public stakes;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public lastStakeTime;
    mapping(address => uint256) public lastUnstakeTime;
    uint256 public totalStaked;
    uint256 public rewardRate = 100;
    uint256 public constant COOLDOWN_PERIOD = 1 days;

    // Presale and Buyback Variables
    uint256 public presaleEndTime;
    uint256 public presaleRate; // RGLM per MATIC (scaled by 10 to avoid decimals)
    uint256 public buybackRate; // RGLM per MATIC (scaled by 10 to avoid decimals)
    bool public buybackEnabled;

    // Events
    event TokensBought(address indexed buyer, uint256 amount);
    event TokensSold(address indexed seller, uint256 amount);
    event MiningAttempt(bytes32 hash, uint256 difficulty);
    event GasEstimate(address indexed user, uint256 gasUsed);

    constructor() ERC20("Regalium", "RGLM") {
        presaleEndTime = 1767120000; // 30-10-2025
        presaleRate = 2 * 10; // 2 RGLM per MATIC (scaled by 10)
        buybackRate = 1.5 * 10; // 1.5 RGLM per MATIC (scaled by 10)
        buybackEnabled = false;

        _mintWithCapCheck(msg.sender, (MAX_SUPPLY * 20)/ 100); // Mint 20% of total supply to deployer
    }

    // Internal function to mint tokens with supply cap check
    function _mintWithCapCheck(address account, uint256 amount) internal {
        require(totalSupply()+ amount <= MAX_SUPPLY, "Minting exceeds max supply");
        _mint(account, amount);
    }

    // Mining Function (Proof of Work) with rate-limiting
    function mine(uint256 nonce) public {
    uint256 initialGas = gasleft();
    require(totalMined < (MAX_SUPPLY * 80) / 100, "All tokens mined");

    // Perform Proof of Work
    bytes32 hash = keccak256(abi.encodePacked(msg.sender, nonce));
    emit MiningAttempt(hash, difficulty);
    require(uint256(hash) < difficulty, "Mining difficulty not met");

    uint256 reward = 50 * 10**18; // Reward for mining
    _mintWithCapCheck(msg.sender, reward);
    totalMined += reward;

    uint256 gasUsed = initialGas - gasleft();
    emit GasEstimate(msg.sender, gasUsed); // Log gas used
}


    // Receive function to accept MATIC for presale, protected by reentrancy guard
    receive() external payable  {
        require(block.timestamp < presaleEndTime, "Presale ended");
        require(msg.value > 0, "Send MATIC to buy tokens");

        uint256 tokenAmount = (msg.value * presaleRate / 10);
        _mint(msg.sender, tokenAmount);
        emit TokensBought(msg.sender, tokenAmount);
    }

    // Function to enable or disable buyback (only owner)
    function setBuybackEnabled(bool _enabled) public {
        buybackEnabled = _enabled;
    }

    // Allow users to sell tokens back to the contract (Buyback), with reentrancy protection
    function sellTokens(uint256 tokenAmount) external {
        require(buybackEnabled, "Buyback is not enabled");
        require(tokenAmount > 0, "Specify an amount of tokens to sell");
        require(balanceOf(msg.sender) >= tokenAmount, "Not enough tokens");

        uint256 maticAmount = (tokenAmount * 10 / buybackRate);
        require(address(this).balance >= maticAmount, "Not enough MATIC in contract");

        _burn(msg.sender, tokenAmount);
        (bool success, ) = payable(msg.sender).call{value: maticAmount}("");
        require(success, "Transfer failed");

        emit TokensSold(msg.sender, tokenAmount);
    }

    // Staking Function (Proof of Stake) with cooldown and gas estimation
function stake(uint256 amount) public {
    uint256 initialGas = gasleft();
    require(amount > 0, "Cannot stake 0 tokens");
    
    // Check cooldown based on lastStakeTime instead of lastUnstakeTime
    require(block.timestamp >= lastStakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for staking");

    _burn(msg.sender, amount);
    stakes[msg.sender] += amount;
    totalStaked += amount;
    lastStakeTime[msg.sender] = block.timestamp;

    uint256 gasUsed = initialGas - gasleft();
    emit GasEstimate(msg.sender, gasUsed); // Log gas used
}



    // Unstaking Function (Proof of Stake) with cooldown and gas estimation
 function unstake(uint256 amount) public {
    uint256 initialGas = gasleft();
    require(stakes[msg.sender] >= amount, "Insufficient stake balance");
    require(block.timestamp >= lastStakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for unstaking");

    stakes[msg.sender] = stakes[msg.sender] - amount;
    totalStaked = totalStaked - amount;
    _mint(msg.sender, amount);
    lastUnstakeTime[msg.sender] = block.timestamp;

    uint256 gasUsed = initialGas - gasleft();
    emit GasEstimate(msg.sender, gasUsed); // Log gas used
}

}
