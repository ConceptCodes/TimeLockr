// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: create a mapping of users to their 'activity' and find a way to add those power users to whitelist
// TODO: add validations for invalid addresses

/**
 * @title TimeLockr
 * @author conceptcodes.eth
 * @notice A simple smart contract to store encrypted messages on-chain for a lockup peroid.
 * @notice For this service you pay a small fee in the native token.
 * @dev The message is encrypted with the recipient's public key from the dApp.
 */
contract TimeLockr is Ownable {
    /**
     * @notice Error definitions.
     * @dev Most of these validations are done on the dApp side.
     *      But we add them here incase you want to use the contract directly.
     */

    /// @dev Emitted when you supply too low of a fee.
    error InsufficientFunds(address _user, uint256 _amount, uint256 _fee);

    /// @dev Emitted when your locktime is too short.
    error InvalidLockTime(uint256 _timeLocked);

    /// @dev Emitted if the message is empty.
    error EmptyMessage(address _user, uint256 _timestamp);

    /// @dev Emitted if you try to unlock a message that is still locked.
    error MessageStillLocked(bytes32 messageId, uint256 _timestamp);

    uint256 public FEE = 1 ether;
    uint256 public MIN_LOCK_TIME_IN_SECONDS = 60; // 1 minute

    struct Message {
        string encryptedMessage;
        uint256 timeLocked;
    }

    /**
     * @notice Mapping of messages.
     * @dev We set this to public so that the dApp can display your messages.
     * @dev Every user will have a mapping of messages with [messageId => Message]
     */
    mapping(address => mapping(bytes32 => Message)) public messages;

    address[] public whitelist; // Whitelisted addresses that don't need to pay the fee.

    /**
     * @notice Emitted when a message is locked.
     * @param _user The address of the user.
     * @param _messageId The id of the message.
     * @param _timestamp The timestamp of when the message was locked.
     */
    event MessageLocked(
        address indexed _user,
        bytes32 _messageId,
        uint256 _timestamp
    );

    /**
     * @notice Emitted when a message is unlocked.
     * @param _user The address of the sender.
     * @param _timestamp The time the message was unlocked.
     */
    event MessageUnlocked(address indexed _user, uint256 _timestamp);

    /**
     * @notice Emitted when fee is updated.
     * @param _old The old fee.
     * @param _fee The new fee.
     * @param _timestamp The timestamp of when the fee was updated.
     */
    event FeeUpdated(uint256 _old, uint256 _fee, uint256 _timestamp);

    /**
     * @notice Emitted when the minimum lock up time is updated.
     * @param _prev The old lock up time.
     * @param _lockTime The new lock up time.
     * @param _timestamp The timestamp of when the minimum lock time was updated.
     */
    event MinimumLockUpTimeUpdated(
        uint256 _prev,
        uint256 _lockTime,
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
     * @notice Lock up a message.
     * @dev The message is encrypted with their public key from the dApp.
     * @dev We go through our validaitons and then store the message.
     * @param _user The address of the user.
     * @param _message The message to lock up.
     * @param _timeLocked The time the message is locked for.
     */
    function lockMessage(
        address _user,
        string calldata _message,
        uint256 _timeLocked
    ) public payable {
        bool whitelisted = false;
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == msg.sender) {
                whitelisted = true;
                break;
            }
        }

        if (!whitelisted && msg.sender != owner()) {
            if (msg.value >= FEE) {
                payable(owner()).transfer(msg.value);
            } else {
                revert InsufficientFunds(msg.sender, msg.value, FEE);
            }
        }

        if (_timeLocked < MIN_LOCK_TIME_IN_SECONDS) {
            revert InvalidLockTime(_timeLocked);
        }

        if (bytes(_message).length == 0) {
            revert EmptyMessage(_user, block.timestamp);
        }

        bytes32 messageId = keccak256(
            abi.encodePacked(_user, block.timestamp, _message, block.coinbase)
        );

        messages[_user][messageId] = Message({
            encryptedMessage: _message,
            timeLocked: block.timestamp + _timeLocked
        });

        emit MessageLocked(_user, messageId, block.timestamp);
    }

    /**
     * @notice Unlock a message.
     * @dev The message is deleted from the mapping after it is unlocked.
     * @dev We return the message so that it can be decrypted
     *      with the users private key on the dApp side.
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
            revert MessageStillLocked(_messageId, block.timestamp);
        }
    }

    /**
     * @notice Get the remaining time for a message.
     * @dev We verify that you own this message.
     * @param _messageId The id of the message.
     * @return timeLeft The remaining time.
     */
    function getRemainingTime(
        bytes32 _messageId
    ) public view returns (uint256 timeLeft) {
        Message memory message = messages[msg.sender][_messageId];
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
            block.timestamp
        );
        MIN_LOCK_TIME_IN_SECONDS = _minimumLockTime;
    }

    /**
     * @notice Add an address to the whitelist.
     * @param _address The address to add.
     * @dev We use onlyOwner modifier to restrict access
     */
    function addToWhitelist(address _address) public onlyOwner {
        whitelist.push(_address);
    }

    /**
     * @notice Remove an address from the whitelist.
     * @param _address The address to remove.
     * @dev We use onlyOwner modifier to restrict access
     */
    function removeFromWhitelist(address _address) public onlyOwner {
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == _address) {
                whitelist[i] = whitelist[whitelist.length - 1];
                whitelist.pop();
                break;
            }
        }
    }
}
