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

    constructor(address initialOwner) ERC20("Regalium Token", "RGLM") Ownable(initialOwner) {
        _mintWithCapCheck(initialOwner, MAX_SUPPLY * 20 / 100); // Mint 20% of total supply to initialOwner
        admins.push(initialOwner);
        isAdmin[initialOwner] = true;
    }

    // Internal function to mint tokens with supply cap check
    function _mintWithCapCheck(address account, uint256 amount) internal {
        require(totalSupply() + amount <= MAX_SUPPLY, "Minting exceeds max supply");
        _mint(account, amount);
    }

    // PoW Mining Function
    function mine(uint256 nonce) public {
        require(totalMined < MAX_SUPPLY * 80 / 100, "All tokens mined");

        bytes32 hash = keccak256(abi.encodePacked(msg.sender, nonce));
        require(uint256(hash) < difficulty, "Mining difficulty not met");

        uint256 reward = 50 * 10**18; // Reward for mining
        _mintWithCapCheck(msg.sender, reward);
        totalMined += reward;
    }

    // Staking Function (PoS)
    function stake(uint256 amount) public {
        require(amount > 0, "Cannot stake 0 tokens");
        require(block.timestamp >= lastUnstakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for staking");

        _burn(msg.sender, amount);
        stakes[msg.sender] += amount;
        totalStaked += amount;
        lastStakeTime[msg.sender] = block.timestamp;
    }

    // Unstaking Function (PoS)
    function unstake(uint256 amount) public {
        require(stakes[msg.sender] >= amount, "Insufficient stake balance");
        require(block.timestamp >= lastStakeTime[msg.sender] + COOLDOWN_PERIOD, "Cooldown period not met for unstaking");

        stakes[msg.sender] -= amount;
        totalStaked -= amount;
        _mint(msg.sender, amount);
        lastUnstakeTime[msg.sender] = block.timestamp;
    }

    // Withdraw Rewards Function (PoS)
    function withdrawRewards() public {
        uint256 reward = calculateReward(msg.sender);
        require(reward > 0, "No rewards to withdraw");
        rewards[msg.sender] = 0;
        _mint(msg.sender, reward);
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

    // Admin functions
    function addAdmin(address newAdmin) public onlyOwner {
        require(!isAdmin[newAdmin], "Already an admin");
        isAdmin[newAdmin] = true;
        admins.push(newAdmin);
    }

    function removeAdmin(address adminToRemove) public onlyOwner {
        require(isAdmin[adminToRemove], "Not an admin");
        require(admins.length > 1, "Cannot remove the last admin");

        isAdmin[adminToRemove] = false;
        for (uint256 i = 0; i < admins.length; i++) {
            if (admins[i] == adminToRemove) {
                admins[i] = admins[admins.length - 1];
                admins.pop();
                break;
            }
        }
    }

    function setDifficulty(uint256 _difficulty) public onlyAdmin {
        difficulty = _difficulty;
    }

    function setRewardRate(uint256 _rewardRate) public onlyAdmin {
        rewardRate = _rewardRate;
    }

    function changeOwner(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Invalid new owner");
        _transferOwnership(newOwner);
    }

    function getAdmins() public view returns (address[] memory) {
        return admins;
    }
}
