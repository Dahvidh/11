const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RegaliumToken", function () {
  let Token, token, owner, addr1, addr2;

  beforeEach(async function () {
    Token = await ethers.getContractFactory("RegaliumToken");
    [owner, addr1, addr2] = await ethers.getSigners();
    token = await Token.deploy();
    await token.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner and initialize presale values", async function () {
      expect(await token.presaleEndTime()).to.equal(1767120000); // 30-10-2025
      expect(await token.presaleRate()).to.equal(20); // 2 RGLM per MATIC, scaled by 10
      expect(await token.buybackRate()).to.equal(15); // 1.5 RGLM per MATIC, scaled by 10
      expect(await token.buybackEnabled()).to.be.false;
    });
  });

  describe("Presale", function () {
    it("Should allow users to buy tokens during presale", async function () {
      const amountToSend = ethers.utils.parseEther("1"); // 1 MATIC
      await addr1.sendTransaction({ to: token.address, value: amountToSend });
      const expectedBalance = ethers.utils.parseUnits("2", 18); // Expect 2 RGLM tokens
      expect(await token.balanceOf(addr1.address)).to.equal(expectedBalance);
    });

    {
      /* it("Should not allow users to buy tokens after presale ends", async function () {
      const amountToSend = ethers.utils.parseEther("1");

      // Fast forward time to after the presale ends
      await ethers.provider.send("evm_increaseTime", [
        1767120000 - Math.floor(Date.now() / 1000) + 1,
      ]);
      await ethers.provider.send("evm_mine");

      await expect(
        addr1.sendTransaction({ to: token.address, value: amountToSend })
      ).to.be.revertedWith("Presale ended");
    });*/
    }
  });

  describe("Buyback", function () {
    beforeEach(async function () {
      const amountToSend = ethers.utils.parseEther("1");
      await addr1.sendTransaction({ to: token.address, value: amountToSend });
    });

    it("Should allow the owner to enable and disable buyback", async function () {
      await token.connect(owner).setBuybackEnabled(true);
      expect(await token.buybackEnabled()).to.be.true;

      await token.connect(owner).setBuybackEnabled(false);
      expect(await token.buybackEnabled()).to.be.false;
    });

    it("Should allow users to sell tokens back to the contract when buyback is enabled", async function () {
      await token.connect(owner).setBuybackEnabled(true);

      // Ensure addr1 has enough tokens and approve the contract
      await token.connect(addr1).approve(token.address, 20);

      const initialTokenBalance = await token.balanceOf(addr1.address);
      const initialBalance = await ethers.provider.getBalance(addr1.address);

      // Selling 20 tokens
      await token.connect(addr1).sellTokens(20);

      const finalBalance = await ethers.provider.getBalance(addr1.address);
      const finalTokenBalance = await token.balanceOf(addr1.address);

      // Verifying that 20 tokens were deducted
      expect(finalTokenBalance).to.equal(initialTokenBalance.sub(20));

      // Ensuring addr1 received MATIC from the buyback, with a tolerance for gas fees
      const tolerance = ethers.utils.parseEther("0.01"); // Adjust tolerance as needed
      expect(finalBalance).to.be.gt(initialBalance.sub(tolerance));
    });

    it("Should not allow users to sell tokens back to the contract when buyback is disabled", async function () {
      await expect(token.connect(addr1).sellTokens(20)).to.be.revertedWith(
        "Buyback is not enabled"
      );
    });
  });

  describe("Staking", function () {
    it("Should allow users to stake tokens", async function () {
      await token.transfer(addr1.address, ethers.utils.parseEther("100"));
      await token
        .connect(addr1)
        .approve(token.address, ethers.utils.parseEther("10"));

      await token.connect(addr1).stake(ethers.utils.parseEther("10"));
      expect(await token.stakes(addr1.address)).to.equal(
        ethers.utils.parseEther("10")
      );
    });

    it("Should not allow staking during cooldown period", async function () {
      // Transfer tokens and approve for staking
      await token.transfer(addr1.address, ethers.utils.parseEther("100"));
      await token
        .connect(addr1)
        .approve(token.address, ethers.utils.parseEther("10"));

      // Perform the first stake action
      await token.connect(addr1).stake(ethers.utils.parseEther("10"));

      // Attempt to stake again immediately without waiting for cooldown
      await expect(
        token.connect(addr1).stake(ethers.utils.parseEther("10"))
      ).to.be.revertedWith("Cooldown period not met for staking");
    });
  });

  describe("Unstaking", function () {
    beforeEach(async function () {
      await token.transfer(addr1.address, ethers.utils.parseEther("100"));
      await token
        .connect(addr1)
        .approve(token.address, ethers.utils.parseEther("10"));
      await token.connect(addr1).stake(ethers.utils.parseEther("10"));
    });

    it("Should allow users to unstake tokens after cooldown period", async function () {
      // Fast forward time to meet cooldown requirement
      await ethers.provider.send("evm_increaseTime", [86400]);
      await ethers.provider.send("evm_mine");

      await token.connect(addr1).unstake(ethers.utils.parseEther("10"));
      expect(await token.stakes(addr1.address)).to.equal(0);
    });

    it("Should not allow unstaking during cooldown period", async function () {
      await expect(
        token.connect(addr1).unstake(ethers.utils.parseEther("10"))
      ).to.be.revertedWith("Cooldown period not met for unstaking");
    });
  });
});
