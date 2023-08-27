# TimeLockr Smart Contract

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

TimeLockr is a simple smart contract built on the Ethereum blockchain that allows users to store and lock up encrypted messages on-chain. The messages can be unlocked after a specified time period. This contract provides a secure and decentralized way to store sensitive information.

## Features

- Lock encrypted messages on the blockchain.
- Set a time duration for locking the messages.
- Unlock messages after the specified time has passed.
- Flexible fee structure based on the locking duration.
- Whitelist feature for exempting certain addresses from paying fees.

## Events

| Name                  | Parameters                                           | Description                                    |
|-----------------------|------------------------------------------------------|------------------------------------------------|
| **MessageLocked**     | `_user` (address), `messageId` (bytes32), `timestamp` (uint256) | Emitted when a message is locked.             |
| **MessageUnlocked**   | `_user` (address), `timestamp` (uint256)            | Emitted when a message is unlocked.           |
| **FeeUpdated**        | `prevFee` (uint256), `fee` (uint256), `timestamp` (uint256) | Emitted when the fee is updated.              |
| **MinimumLockUpTimeUpdated** | `prevLockTime` (uint256), `lockTime` (uint256), `timestamp` (uint256) | Emitted when the minimum lock time is updated. |
| **AddedToWhitelist**  | `user` (address), `timestamp` (uint256)             | Emitted when an address is added to the whitelist. |
| **RemovedFromWhitelist** | `user` (address), `timestamp` (uint256)          | Emitted when an address is removed from the whitelist. |


## Prerequisites

- Ethereum wallet or compatible browser extension (e.g., MetaMask).
- Smart contract development environment (e.g., Remix, Hardhat).

## Usage

1. Deploy the TimeLockr contract on the Ethereum blockchain.
2. Interact with the contract functions using Ethereum wallets or develop custom applications.

## Flows

### Locking a Message

1. Call the `lockMessage` function with the recipient's address, the encrypted message, and the desired lock time.
2. If not whitelisted, ensure that the transaction value is sufficient based on the locking duration.
3. The message will be stored and locked up on the blockchain.

### Unlocking a Message

1. Call the `unlockMessage` function with the message ID.
2. If the time has passed the lock-up period, the message will be unlocked and added to the user's messages.

### Checking Remaining Time

1. Call the `getRemainingTime` function with the message ID to check the remaining lock time for a message.

### Retrieving Unlocked Messages

1. Call the `getMessage` function with the message ID to retrieve an unlocked message.

### Updating Fee and Minimum Lock Time (Restricted to Contract owner)

1. Call the `updateFee` function to update the fee required for locking messages.
2. Call the `updateMinimumLockTime` function to update the minimum lock time.

### Managing Whitelist (Restricted to Contract owner)

1. Call the `addToWhitelist` function to add an address to the whitelist for fee exemption.
2. Call the `removeFromWhitelist` function to remove an address from the whitelist.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

