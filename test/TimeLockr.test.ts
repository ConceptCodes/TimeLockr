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
    const whitelist = await contract.getWhitelist();

    return {
      contract,
      owner,
      otherAccount,
      balance,
      fee,
      minLockTime,
      whitelist,
    };
  }

  describe("Deployment", function () {
    it("Should set deployer to owner", async function () {
      const { contract, owner } = await loadFixture(deployTimeLockr);
      expect(await contract.owner()).to.equal(owner.address);
    });

    it("Balance should be empty", async function () {
      const { balance } = await loadFixture(deployTimeLockr);
      expect(balance).to.equal(ethers.utils.parseEther("0"));
    });

    it("Whitelist should be empty", async function () {
      const { whitelist } = await loadFixture(deployTimeLockr);
      expect(whitelist).to.be.empty;
    });
  });

  describe("Locking A Message", function () {
    describe("Fee", function () {
      it("Throw Error: Insufficient Funds/No Funds", async function () {
        const { contract, minLockTime, otherAccount } = await loadFixture(
          deployTimeLockr
        );
        const message = "Hello World";
        const duration = minLockTime;
        const address = otherAccount.address;

        await expect(
          contract.connect(otherAccount).lockMessage(address, message, duration)
        ).to.be.revertedWithCustomError(contract, "InsufficientFunds");
      });

      it("Throw Error: Insufficient Funds/Not Enough Funds", async function () {
        const { contract, minLockTime, otherAccount } = await loadFixture(
          deployTimeLockr
        );
        const message = "Hello World";
        const duration = minLockTime;
        const address = otherAccount.address;

        const amount = ethers.utils.parseEther("0.5");

        await expect(
          contract
            .connect(otherAccount)
            .lockMessage(address, message, duration, {
              value: amount,
            })
        ).to.be.revertedWithCustomError(contract, "InsufficientFunds");
      });

      it("Owner: Bypass Fee/Lock Message", async function () {
        const { contract, minLockTime, owner } = await loadFixture(
          deployTimeLockr
        );
        const message = "Hello World";

        const tx = await contract.lockMessage(
          owner.address,
          message,
          minLockTime
        );
        const data = await ethers.provider.getTransactionReceipt(tx.hash);
        const timestamp = await ethers.provider.getBlock(data.blockNumber);

        const messageId = ethers.utils.solidityKeccak256(
          ["address", "uint256", "string", "address", "uint256"],
          [owner.address, timestamp.timestamp, message, tx.from, minLockTime]
        );

        await expect(contract)
          .to.emit(contract, "MessageLocked")
          .withArgs(owner.address, messageId, timestamp.timestamp);
      });

      // it("Owner: Lock Message for other address", async function () {
      //   const { contract, minLockTime, otherAccount } = await loadFixture(
      //     deployTimeLockr
      //   );
      //   const message = "Hello World";
      //   const address = otherAccount.address;

      //   const tx = await contract.lockMessage(address, message, minLockTime);
      //   const data = await ethers.provider.getTransactionReceipt(tx.hash);
      //   const timestamp = await ethers.provider.getBlock(data.blockNumber);

      //   const messageId = ethers.utils.solidityKeccak256(
      //     ["address", "uint256", "string", "address", "uint256"],
      //     [address, timestamp.timestamp, message, tx.from, minLockTime]
      //   );

      //   await expect(contract)
      //     .to.emit(contract, "MessageLocked")
      //     .withArgs(address, messageId, timestamp.timestamp);
      // });

      // it("Owner: Pay Fee/Lock Message", async function () {
      //   const { contract, minLockTime, fee, owner } = await loadFixture(
      //     deployTimeLockr
      //   );
      //   const message = "Hello World";

      //   const tx = await contract.lockMessage(
      //     owner.address,
      //     message,
      //     minLockTime,
      //     {
      //       value: fee,
      //     }
      //   );
      //   const data = await ethers.provider.getTransactionReceipt(tx.hash);
      //   const timestamp = await ethers.provider.getBlock(data.blockNumber);

      //   const messageId = ethers.utils.solidityKeccak256(
      //     ["address", "uint256", "string", "address", "uint256"],
      //     [owner.address, timestamp.timestamp, message, tx.from, minLockTime]
      //   );

      //   await expect(contract)
      //     .to.emit(contract, "MessageLocked")
      //     .withArgs(owner.address, messageId, timestamp.timestamp);
      // });

      // it("Whitelisted: bypass fee & lock message", async function () {
      //   const { contract, minLockTime, fee, owner, otherAccount } =
      //     await loadFixture(deployTimeLockr);
      //   const message = "Hello World";
      //   const duration = minLockTime;
      //   const address = otherAccount.address;

      //   await contract.addToWhitelist(address, {
      //     from: owner.address,
      //   });

      //   const tx = await contract.lockMessage(address, message, duration);

      //   const data = await ethers.provider.getTransactionReceipt(tx.hash);
      //   const timestamp = await ethers.provider.getBlock(data.blockNumber);

      //   const messageId = ethers.utils.solidityKeccak256(
      //     ["address", "uint256", "string", "uint256"],
      //     [address, duration, message, tx.coinbase]
      //   );

      //   await expect(contract)
      //     .to.emit(contract, "MessageLocked")
      //     .withArgs(address, messageId, timestamp.timestamp);
      // });

      // it("Pay Fee: lock message", async function () {
      //   const { contract, minLockTime, fee, otherAccount } = await loadFixture(
      //     deployTimeLockr
      //   );
      //   const message = "Hello World";
      //   const duration = minLockTime;
      //   const address = otherAccount.address;

      //   const tx = await contract.lockMessage(address, message, duration, {
      //     value: fee,
      //   });

      //   const data = await ethers.provider.getTransactionReceipt(tx.hash);
      //   const timestamp = await ethers.provider.getBlock(data.blockNumber);

      //   const messageId = ethers.utils.solidityKeccak256(
      //     ["address", "uint256", "string", "uint256"],
      //     [address, duration, message, tx.coinbase]
      //   );

      //   await expect(contract)
      //     .to.emit(contract, "MessageLocked")
      //     .withArgs(address, messageId, timestamp.timestamp);
      // });
    });

    describe("Lockup Time", function () {});
  });

  // describe("Unlocking A Message", function () {});

  // describe("Access Control", function () {});
});
