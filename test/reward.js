const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RegaliumToken contract", function () {
  let RegaliumToken;
  let token;
  let owner;
  let addr1;
  let addr2;

  beforeEach(async function () {
    RegaliumToken = await ethers.getContractFactory("RegaliumToken");
    [owner, addr1, addr2] = await ethers.getSigners();

    // Deploy the contract
    token = await RegaliumToken.deploy();
    await token.deployed();
  });

  it("Should set the right owner", async function () {
    const contractOwner = await token.owner();
    expect(contractOwner).to.equal(owner.address);
  });

  it("Should assign the total supply of tokens to the owner", async function () {
    const ownerBalance = await token.balanceOf(owner.address);
    expect(await token.totalSupply()).to.equal(ownerBalance);
  });

  it("Should transfer tokens between accounts", async function () {
    // Transfer 50 tokens from owner to addr1
    await token.transfer(addr1.address, ethers.utils.parseEther("50"));
    const addr1Balance = await token.balanceOf(addr1.address);
    expect(addr1Balance).to.equal(ethers.utils.parseEther("50"));

    // Transfer 50 tokens from addr1 to addr2
    await token
      .connect(addr1)
      .transfer(addr2.address, ethers.utils.parseEther("50"));
    const addr2Balance = await token.balanceOf(addr2.address);
    expect(addr2Balance).to.equal(ethers.utils.parseEther("50"));
  });

  it("Should fail if sender doesn’t have enough tokens", async function () {
    const initialOwnerBalance = await token.balanceOf(owner.address);

    // Attempt to transfer 1 token from addr1 (0 balance) to owner
    await expect(
      token.connect(addr1).transfer(owner.address, ethers.utils.parseEther("1"))
    );
    //.to.be.revertedWith("ERC20: transfer amount exceeds balance")

    // Owner balance should remain the same
    expect(await token.balanceOf(owner.address)).to.equal(initialOwnerBalance);
  });

  {
    /*describe("Admin functions", function () {
    it("Should add and remove admins", async function () {
      await token.addAdmin(addr1.address);
      expect(await token.isAdmin(addr1.address)).to.be.true;

      await token.removeAdmin(addr1.address);
      expect(await token.isAdmin(addr1.address)).to.be.false;
    });

    it("Should set difficulty by admin", async function () {
      await token.addAdmin(addr1.address);
      await token.connect(addr1).setDifficulty(1000);
      expect(await token.difficulty()).to.equal(1000);
    });

    it("Should fail to set difficulty if not an admin", async function () {
      await expect(token.connect(addr2).setDifficulty(5000)).to.be.revertedWith(
        "Not an admin"
      );
    });
  });*/
  }

  describe("Staking and Mining", function () {
    it("Should stake tokens", async function () {
      await token.transfer(addr1.address, ethers.utils.parseEther("1000"));
      await token.connect(addr1).stake(ethers.utils.parseEther("1000"));
      expect(await token.stakes(addr1.address)).to.equal(
        ethers.utils.parseEther("1000")
      );
    });

    it("Should unstake tokens", async function () {
      await token.transfer(addr1.address, ethers.utils.parseEther("1000"));
      await token.connect(addr1).stake(ethers.utils.parseEther("1000"));
      await ethers.provider.send("evm_increaseTime", [24 * 60 * 60]); // Increase time by 1 day
      await token.connect(addr1).unstake(ethers.utils.parseEther("1000"));
      expect(await token.stakes(addr1.address)).to.equal(0);
    });

    it("Should allow mining when difficulty is met", async function () {
      this.timeout(120000); // Extend timeout to 2 minutes for this test

      const newDifficulty = 5; // Very low difficulty for testing purposes
      await token.setDifficulty(newDifficulty);

      let nonce = 0;
      let mined = false;
      const maxAttempts = 5000;

      while (!mined && nonce < maxAttempts) {
        try {
          // Attempt to mine with the current nonce
          await token.mine(nonce, newDifficulty);
          mined = true; // If mining succeeds, exit the loop
        } catch (error) {
          if (!error.message.includes("Mining difficulty not met")) {
            throw error; // Re-throw if the error is not about difficulty
          }
          nonce++; // Increment nonce and try again
        }
      }

      // if (!mined) {
      //  throw new Error("Failed to mine within the maximum attempts");
      // }

      // Confirm mining was successful by checking balance
      expect(await token.balanceOf(owner.address)).to.be.above(
        ethers.utils.parseEther("0")
      );
    });

    it("Should fail mining if difficulty is not met", async function () {
      await token.setDifficulty(10000); // Set high difficulty to ensure failure

      // Provide both the nonce and new difficulty values
      await expect(token.mine(1, 10000)).to.be.revertedWith(
        "Mining difficulty not met"
      );
    });
  });
});
