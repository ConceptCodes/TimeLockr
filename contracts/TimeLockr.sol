// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// TODO: create a mapping of users to their 'activity' and find a way to add those power users to whitelist

/**
 * @title TimeLockr
 * @author conceptcodes.eth x jhilert.eth
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

    /// @dev Emitted when the fee is too low.
    error InsufficientFunds(uint256 fee, uint256 timestamp);

    /// @dev Emitted if the message is empty.
    error EmptyMessage(address user, uint256 timestamp);

    /// @dev Emitted if you try to unlock a message that is still locked.
    error MessageStillLocked(bytes32 messageId, uint256 timestamp);

    uint256 public FEE = .5 ether;
    uint256 public MIN_LOCK_TIME_IN_SECONDS = 60; // 1 minute

    struct Message {
        string encryptedMessage;
        uint256 timeLocked;
    }

    /**
     * @notice Mapping of messages.
     * @dev we set this to private so that only the contract can access it.
     * @dev every user will have a mapping of messages with [messageId => Message]
     */
    mapping(address => mapping(bytes32 => Message)) private vault;

    /**
     * @notice Mapping of user messages.
     * @dev we set this to public so that the dApp can access it.
     * @dev every user will have an array of messageIds with [address => messageId[]]
     */
    mapping(address => bytes32[]) public messages;

    /// @notice Whitelisted addresses that don't need to pay the fee.
    address[] public whitelist;

    /**
     * @notice Emitted when a message is locked.
     * @param user The address of the user.
     * @param messageId The id of the message.
     * @param timestamp The timestamp of when the message was locked.
     */
    event MessageLocked(
        address indexed user,
        bytes32 messageId,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a message is unlocked.
     * @param user The address of the sender.
     * @param timestamp The time the message was unlocked.
     */
    event MessageUnlocked(address indexed user, uint256 timestamp);

    /**
     * @notice Emitted when the fee is updated.
     * @param prevFee The old fee.
     * @param fee The new fee.
     * @param timestamp The timestamp of when the fee was updated.
     */
    event FeeUpdated(uint256 prevFee, uint256 fee, uint256 timestamp);

    /**
     * @notice Emitted when the minimum lock up time is updated.
     * @param prevLockTime The old lock up time.
     * @param lockTime The new lock up time.
     * @param timestamp The timestamp of when the minimum lock time was updated.
     */
    event MinimumLockUpTimeUpdated(
        uint256 prevLockTime,
        uint256 lockTime,
        uint256 timestamp
    );

    /**
     * @notice Emitted when a new address is added to the whitelist.
     * @param user The address that was added.
     * @param timestamp The timestamp of when the address was added.
     */
    event AddedToWhitelist(address user, uint256 timestamp);

    /**
     * @notice Emitted when an address is removed from the whitelist.
     * @param user The address that was removed.
     * @param timestamp The timestamp of when the address was removed.
     */
    event RemovedFromWhitelist(address user, uint256 timestamp);

    constructor() {}

    function getMinimumLockTime() public view returns (uint256) {
        return MIN_LOCK_TIME_IN_SECONDS;
    }

    /**
     * @notice Lock up a message.
     * @notice timeLocked < 1 day = base fee,
     *         timeLocked > 1 day = base fee + .25 matic * days locked
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
        require(_user != address(0));

        bool whitelisted = false;
        for (uint256 i = 0; i < whitelist.length; i++) {
            if (whitelist[i] == msg.sender) {
                whitelisted = true;
                break;
            }
        }

        if (!whitelisted || msg.sender != owner()) {
            if (_timeLocked > 1 days) {
                if (msg.value < FEE + ((_timeLocked / 1 days) * .25 ether)) {
                    revert InsufficientFunds(msg.value, block.timestamp);
                }
            } else {
                if (msg.value < FEE) {
                    revert InsufficientFunds(msg.value, block.timestamp);
                }
            }
        }

        if (bytes(_message).length == 0) {
            revert EmptyMessage(_user, block.timestamp);
        }

        bytes32 messageId = keccak256(
            abi.encodePacked(_user, block.timestamp, _message)
        );

        vault[_user][messageId] = Message({
            encryptedMessage: _message,
            timeLocked: block.timestamp + _timeLocked
        });

        emit MessageLocked(_user, messageId, block.timestamp);
    }

    /**
     * @notice Unlock a message.
     * @param _messageId The id of the message.
     * @dev The message is deleted from the mapping after it is unlocked.
     * @dev We return the message so that it can be decrypted
     *      with the users private key on the dApp side.
     */
    function unlockMessage(bytes32 _messageId) public {
        Message memory message = vault[msg.sender][_messageId];

        if (block.timestamp >= message.timeLocked) {
            delete vault[msg.sender][_messageId];
            emit MessageUnlocked(msg.sender, block.timestamp);
            messages[msg.sender].push(_messageId);
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
        Message memory message = vault[msg.sender][_messageId];
        if (block.timestamp >= message.timeLocked) {
            return 0;
        } else {
            return message.timeLocked - block.timestamp;
        }
    }

    /**
     * @notice Get your messages.
     * @dev We verify that you own this message.
     * @dev We check the messages mapping to only return unlocked messages
     * @return messages all unlocked messages for the user.
     */
    function getMessages() public view returns (string[] memory) {
        string[] memory unlockedMessages;
        for (uint256 i = 0; i < messages[msg.sender].length; i++) {
            bytes32 messageId = messages[msg.sender][i];
            Message memory message = vault[msg.sender][messageId];
            unlockedMessages[i] = message.encryptedMessage;
        }
        return unlockedMessages;
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
        emit AddedToWhitelist(_address, block.timestamp);
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
                emit RemovedFromWhitelist(_address, block.timestamp);
                break;
            }
        }
    }

    receive() external payable {}

    fallback() external payable {
        payable(owner()).transfer(msg.value);
    }
}
