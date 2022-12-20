import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";

describe("TimeLockr", function () {
  async function deployTimeLockr() {
    const [owner, otherAccount] = await ethers.getSigners();

    const TimeLockr = await ethers.getContractFactory("TimeLockr");
    const contract = await TimeLockr.deploy();
    const balance = await ethers.provider.getBalance(contract.address);
    const fee = await contract.getFee();
    const minLockTime = await contract.getMinimumLockTime();

    return { contract, owner, otherAccount, balance, fee, minLockTime };
  }

  describe("Deployment", function () {
    it("Should set the right owner", async function () {
      const { contract, owner } = await loadFixture(deployTimeLockr);

      expect(await contract.owner()).to.equal(owner.address);
    });

    it("Balance should be empty", async function () {
      const { balance } = await loadFixture(deployTimeLockr);
      expect(balance).to.equal(ethers.utils.parseEther("0"));
    });
  });

  describe("Locking A Message", function () {
    it("should throw error if the fee is not paid", async function () {
      const { contract, minLockTime } = await loadFixture(deployTimeLockr);
      const message = "Hello World";

      await expect(
        contract.lockMessage(message, minLockTime)
      ).to.be.revertedWithCustomError(contract, "InsufficientFunds");
    });

    it("should throw an error if lock up period is too short", async function () {
      const { contract, fee, minLockTime } = await loadFixture(deployTimeLockr);
      const message = "Hello World";
      const duration = minLockTime - (1 * 60);

      const amount = ethers.utils.parseEther(`${fee}`);

      await expect(
        contract.lockMessage(message, duration, {
          value: amount,
        })
      ).to.be.revertedWithCustomError(contract, "InvalidLockTime");
    });

    it("should allow you to lock a message", async function () {
      const { contract, minLockTime, fee } = await loadFixture(deployTimeLockr);
      const message = "Hello World";
      const duration = minLockTime;

      const tx = await contract.lockMessage(message, duration, {
        value: fee,
      });

      const data = await ethers.provider.getTransactionReceipt(tx.hash);
      const timestamp = await ethers.provider.getBlock(data.blockNumber);

      const messageId = ethers.utils.solidityKeccak256(
        ["address", "uint256", "string"],
        [tx.from, timestamp.timestamp, message]
      );

      await expect(contract)
        .to.emit(contract, "MessageLocked")
        .withArgs(messageId, duration);
    });
  });

  // describe("Unlocking A Message", function () {
  //   it("should throw an error if messageId does not exist", async function () {
  //     const { contract } = await loadFixture(deployTimeLockr);

  //     const messageId = ethers.utils.solidityKeccak256(
  //       ["address", "uint256", "string"],
  //       ["hello", 1234567890, "world"]
  //     );

  //     await expect(contract.unlockMessage(messageId)).to.Throw;
  //   });

  //   it("should throw an error if the message is locked but the duration is not over", async function () {
  //     const { contract } = await loadFixture(deployTimeLockr);
  //     const message = "Hello World";
  //     const duration = 3600;

  //     const amount = ethers.utils.parseEther("2");

  //     const tx = await contract.lockMessage(message, duration, {
  //       value: amount,
  //     });

  //     const messageId = ethers.utils.solidityKeccak256(
  //       ["address", "uint256", "string"],
  //       [tx.from, tx.timestamp, message]
  //     );

  //     await expect(contract.unlockMessage(message)).to.Throw;

  //     await expect(contract)
  //       .to.emit(contract, "MessageStillLocked")
  //       .withArgs(anyValue(), messageId);
  //   });

  //   it("should allow you to unlock a message", async function () {
  //     const { contract, otherAccount } = await loadFixture(deployTimeLockr);
  //     const message = "Hello World";
  //     const duration = 360;

  //     const amount = ethers.utils.parseEther("2");

  //     const tx = await contract.lockMessage(message, duration, {
  //       value: amount,
  //     });

  //     const messageId = ethers.utils.solidityKeccak256(
  //       ["address", "uint256", "string"],
  //       [tx.from, tx.timestamp, message]
  //     );

  //     await ethers.provider.send("evm_increaseTime", [duration]);

  //     const tx2 = await contract.unlockMessage(messageId);

  //     expect(tx2.data).to.equal(message);

  //     await expect(contract)
  //       .to.emit(contract, "MessageUnlocked")
  //       .withArgs(tx2.from, tx2.timestamp);
  //   });
  // });
});
