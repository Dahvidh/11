// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RegaliumToken is ERC20, ERC20Burnable, Ownable {

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

    address[] public admins;
    mapping(address => bool) public isAdmin;

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    event GasUsageEstimate(uint256 gasUsed);

    constructor() ERC20("Regalium Token", "RGLM") Ownable(msg.sender) {
        _mintWithCapCheck(msg.sender, MAX_SUPPLY * 20 / 100); // Mint 20% of total supply to the contract deployer
        admins.push(msg.sender);
        isAdmin[msg.sender] = true;
    }

    // Internal function to mint tokens with supply cap check
    function _mintWithCapCheck(address account, uint256 amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting exceeds max supply");
        _mint(account, amount);
    }

    function mine(uint256 nonce, uint256 newDifficulty) public {
        uint256 initialGas = gasleft();

        // Set difficulty before mining
        setDifficulty(newDifficulty);
        
        require(totalMined < MAX_SUPPLY * 80 / 100, "All tokens mined");

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, nonce));

        emit MiningAttempt(hash, difficulty);

        require(uint256(hash) < difficulty, "Mining difficulty not met");

        uint256 reward = 50 * 10**18; // Reward for mining
        _mintWithCapCheck(msg.sender, reward);
        totalMined += reward;

        // Emit estimated gas usage
        emit GasUsageEstimate(initialGas - gasleft());
    }

    // Event for tracking mining attempts
    event MiningAttempt(bytes32 hash, uint256 difficulty);

    // Staking Function (PoS) with Gas Estimation
    function stake(uint256 amount) public {
        uint256 initialGas = gasleft();
        
        require(amount > 0, "Cannot stake 0 tokens");
        require(block.timestamp >= lastUnstakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for staking");

        require(balanceOf(msg.sender) >= amount, "ERC20: transfer amount exceeds balance");

        _burn(msg.sender, amount);
        stakes[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;

        // Emit estimated gas usage
        emit GasUsageEstimate(initialGas - gasleft());
    }

    // Unstaking Function (PoS) with Gas Estimation
function unstake(uint256 amount) public {
    uint256 initialGas = gasleft();
    
    require(stakes[msg.sender] >= amount, "Insufficient staked balance");
    require(block.timestamp >= lastStakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for unstaking");

    stakes[msg.sender] -= amount;
    totalStaked -= amount;
    _mint(msg.sender, amount);
    lastUnstakeTime[msg.sender] = block.timestamp;

    // Emit estimated gas usage
    emit GasUsageEstimate(initialGas - gasleft());
}


    // Withdraw Rewards Function (PoS) with Gas Estimation
    function withdrawRewards() public {
        uint256 initialGas = gasleft();
        
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards to withdraw");
        rewards[msg.sender] = 0;
        _mint(msg.sender, reward);

        // Emit estimated gas usage
        emit GasUsageEstimate(initialGas - gasleft());
    }

    // Calculate Rewards for Stakers
    function calculateReward(address staker) public view returns (uint256) {
        uint256 accumulatedReward = stakes[staker] * rewardRate / 10000;

        // Calculate additional reward based on time since last reward
        uint256 lastTime = lastStakeTime[staker];
        if (lastTime > 0) {
            uint256 timeDiff = block.timestamp - lastTime;
            accumulatedReward += stakes[staker] * rewardRate * timeDiff / (10000 * 365 days);
        }

        return accumulatedReward + rewards[staker];
    }

    function setDifficulty(uint256 _difficulty) public onlyAdmin {
        uint256 initialGas = gasleft();
        
        difficulty = _difficulty;

        // Emit estimated gas usage
        emit GasUsageEstimate(initialGas - gasleft());
    }

    function setRewardRate(uint256 _rewardRate) public onlyAdmin {
        uint256 initialGas = gasleft();
        
        rewardRate = _rewardRate;

        // Emit estimated gas usage
        emit GasUsageEstimate(initialGas - gasleft());
    }
}
