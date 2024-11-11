const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("RegaliumToken", function () {
  let RegaliumToken;
  let token;
  let owner;
  let addr1;

  beforeEach(async function () {
    // Get the contract factory for RegaliumToken
    RegaliumToken = await ethers.getContractFactory(
      "contracts/gameintegration.sol:RegaliumToken"
    );

    // Get signers (accounts)
    [owner, addr1] = await ethers.getSigners();

    // Deploy the contract without any constructor arguments
    token = await RegaliumToken.deploy();

    // Wait for the deployment to complete
    await token.deployed();
  });

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      expect(await token.owner()).to.equal(owner.address);
    });

    it("Should assign the initial supply to the owner", async function () {
      const ownerBalance = await token.balanceOf(owner.address);
      expect(await token.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe("In-game purchases", function () {
    beforeEach(async function () {
      await token.transfer(addr1.address, 1000);
    });

    it("Should allow a user to make an in-game purchase", async function () {
      await token.connect(addr1).inGamePurchase(500);
      expect(await token.inGameBalance(addr1.address)).to.equal(500);
      expect(await token.balanceOf(addr1.address)).to.equal(500);
    });

    it("Should emit an InGamePurchase event", async function () {
      await expect(token.connect(addr1).inGamePurchase(500))
        .to.emit(token, "InGamePurchase")
        .withArgs(addr1.address, 500);
    });

    it("Should not allow a user to make an in-game purchase with insufficient balance", async function () {
      await expect(
        token.connect(addr1).inGamePurchase(1500)
      ).to.be.revertedWith("Insufficient token balance");
    });
  });

  describe("Withdraw tokens", function () {
    beforeEach(async function () {
      await token.transfer(addr1.address, 1000);
      await token.connect(addr1).inGamePurchase(500);
    });

    it("Should allow a user to withdraw tokens", async function () {
      await token.connect(addr1).withdrawTokens(200);
      expect(await token.inGameBalance(addr1.address)).to.equal(300);
      expect(await token.balanceOf(addr1.address)).to.equal(700);
    });

    it("Should emit a TokensWithdrawn event", async function () {
      await expect(token.connect(addr1).withdrawTokens(200))
        .to.emit(token, "TokensWithdrawn")
        .withArgs(addr1.address, 200);
    });

    it("Should not allow a user to withdraw more tokens than their in-game balance", async function () {
      await expect(token.connect(addr1).withdrawTokens(600)).to.be.revertedWith(
        "Insufficient in-game balance"
      );
    });
  });

  describe("In-game balance", function () {
    beforeEach(async function () {
      await token.transfer(addr1.address, 1000);
      await token.connect(addr1).inGamePurchase(500);
    });

    it("Should return the correct in-game balance", async function () {
      expect(await token.inGameBalance(addr1.address)).to.equal(500);
    });
  });
});
