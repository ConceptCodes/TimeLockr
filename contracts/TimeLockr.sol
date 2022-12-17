// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title TimeLockr
 * @author conceptcodes.eth
 * @notice A simple smart contract to encrypt and store messages onchain for a lockup peroid.
 * @notice For this service you pay a small fee in MATIC.
 * @dev You sign the transaction with your private key and the message is encrypted with your public key.
 * @dev Encrypted messages are stored on the blockchain and can be accessed by anyone.
 *      The message can only be decrypted by the person who sent it, only after the time lock has expired.
 * @dev A simple smart contract to encrypt and store a message for a specified amount of time.
 */
contract TimeLockr is Ownable {
    error InsufficientFunds(address _user, uint256 _amount, uint256 _fee);

    error InvalidLockTime(uint256 _timeLocked);
    error InvalidMessageId(address _user, bytes32 messageId);
    error InvalidSender(address sender, address user);

    error MessageAlreadyUnlocked(uint256 timeUnlocked);
    error MessageStillLocked(bytes32 messageId);

    uint256 public FEE = 1 ether;
    uint256 public MIN_LOCK_TIME_IN_SECONDS = 60;

    struct Message {
        string encryptedMessage;
        uint256 timeLocked;
    }

    mapping(address => mapping(bytes32 => Message)) private messages;

    /**
     * @notice Emitted when a message is sent.
     * @param _user The address of the sender.
     * @param _messageId The id of the message.
     * @param _timestamp The time the message was sent.
     */
    event MessageLocked(address indexed _user, bytes32 _messageId, uint256 _timestamp);

    /**
     * @notice Emitted when a message is unlocked.
     * @param _user The address of the sender.
     * @param _timestamp The time the message was unlocked.
     */
    event MessageUnlocked(address indexed _user, uint256 _timestamp);

    /**
     * @notice Emitted when fee is updated.
     * @param _fee The new fee.
     * @param _timestamp The timestamp of when the fee was updated.
     */
    event FeeUpdated(uint256 _prevFee, uint256 _fee, uint256 _timestamp);

    /**
     * @notice Emitted when the minimum lock up period is updated.
     * @param _minimumLockTime The new minimum lock up time.
     * @param _timestamp The timestamp of when the minimum lock time was updated.
     */
    event MinimumLockUpTimeUpdated(
        uint256 _prevMinimumLockTime,
        uint256 _minimumLockTime,
        uint256 _timestamp
    );

    constructor() {}

    function getMinimumLockTime() public view returns (uint256) {
        return MIN_LOCK_TIME_IN_SECONDS;
    }

    function getFee() public view returns (uint256) {
        return FEE;
    }

    /**
     * @notice Encrypt and store a message.
     * @dev The message is encrypted with their public key.
     * @param _message The message to encrypt.
     * @param _timeLocked The time the message is locked for.
     */
    function lockMessage(
        address _user,
        string calldata _message,
        uint256 _timeLocked
    ) public payable {
        if (msg.value >= FEE) {
            payable(owner()).transfer(msg.value);
        } else {
            revert InsufficientFunds(msg.sender, msg.value, FEE);
        }

        if (_timeLocked < MIN_LOCK_TIME_IN_SECONDS) {
            revert InvalidLockTime(_timeLocked);
        }

        bytes32 messageId = keccak256(
            abi.encodePacked(_user, block.timestamp, _message, block.coinbase)
        );

        uint256 lockUp = block.timestamp + _timeLocked;

        messages[_user][messageId] = Message({
            encryptedMessage: _message,
            timeLocked: lockUp
        });

        emit MessageLocked(_user, messageId, lockUp);
    }

    /**
     * @notice Unlock a message.
     * @param _messageId The id of the message.
     * @return encryptedMessage The encrypted message.
     */
    function unlockMessage(
        bytes32 _messageId
    ) public returns (string memory encryptedMessage) {
        Message memory message = messages[msg.sender][_messageId];

        if (block.timestamp >= message.timeLocked) {
            delete messages[msg.sender][_messageId];
            emit MessageUnlocked(msg.sender, block.timestamp);
            return message.encryptedMessage;
        } else {
            revert MessageStillLocked(_messageId);
        }
    }

    /**
     * @notice Get the remaining time for a message.
     * @param _messageId The id of the message.
     * @dev we check that the message is owned
     * @return timeLeft The remaining time.
     */
    function getRemainingTime(
        address _user,
        bytes32 _messageId
    ) public view returns (uint256 timeLeft) {
        Message memory message = messages[_user][_messageId];
        if (block.timestamp >= message.timeLocked) {
            return 0;
        } else {
            return message.timeLocked - block.timestamp;
        }
    }

    /**
     * @notice Update the fee.
     * @param _fee The new fee.
     * @dev We use onlyOwner modifier to restrict access
     */
    function updateFee(uint256 _fee) public onlyOwner {
        emit FeeUpdated(FEE, _fee, block.timestamp);
        FEE = _fee;
    }

    /**
     * @notice Update the minimum lock time.
     * @param _minimumLockTime The new minimum lock time.
     * @dev We use onlyOwner modifier to restrict access
     */
    function updateMinimumLockTime(uint256 _minimumLockTime) public onlyOwner {
        emit MinimumLockUpTimeUpdated(
          MIN_LOCK_TIME_IN_SECONDS,
          _minimumLockTime, 
          block.timestamp);
        MIN_LOCK_TIME_IN_SECONDS = _minimumLockTime;
    }
}
