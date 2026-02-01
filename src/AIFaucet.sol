// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AIFaucet
 * @dev Faucet for distributing AI tokens for identity registration
 *
 * Features:
 * - Rate limiting per address
 * - Configurable drip amount
 * - Support for multiple networks (Hanzo, Lux, Zoo testnets)
 * - Emergency pause functionality
 */
contract AIFaucet is Ownable, Pausable {
    IERC20 public aiToken;

    // Faucet configuration
    uint256 public dripAmount; // Amount to send per request
    uint256 public cooldownPeriod; // Time between requests
    uint256 public maxDailyLimit; // Max tokens per day per address

    // Tracking
    mapping(address => uint256) public lastDripTime;
    mapping(address => uint256) public dailyDripAmount;
    mapping(address => uint256) public lastDripDay;

    // Events
    event Drip(address indexed recipient, uint256 amount);
    event ConfigUpdate(uint256 dripAmount, uint256 cooldownPeriod, uint256 maxDailyLimit);
    event FaucetRefill(uint256 amount);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    constructor(
        address _aiToken,
        uint256 _dripAmount,
        uint256 _cooldownPeriod,
        uint256 _maxDailyLimit
    ) Ownable(msg.sender) {
        aiToken = IERC20(_aiToken);
        dripAmount = _dripAmount;
        cooldownPeriod = _cooldownPeriod;
        maxDailyLimit = _maxDailyLimit;
    }

    /**
     * @dev Request tokens from faucet
     */
    function drip() external whenNotPaused {
        require(canDrip(msg.sender), "Cooldown period not elapsed or daily limit reached");

        uint256 currentDay = block.timestamp / 1 days;

        // Reset daily counter if new day
        if (lastDripDay[msg.sender] < currentDay) {
            dailyDripAmount[msg.sender] = 0;
            lastDripDay[msg.sender] = currentDay;
        }

        // Check daily limit
        require(
            dailyDripAmount[msg.sender] + dripAmount <= maxDailyLimit,
            "Daily limit exceeded"
        );

        // Update tracking
        lastDripTime[msg.sender] = block.timestamp;
        dailyDripAmount[msg.sender] += dripAmount;

        // Transfer tokens
        require(
            aiToken.transfer(msg.sender, dripAmount),
            "Token transfer failed"
        );

        emit Drip(msg.sender, dripAmount);
    }

    /**
     * @dev Check if address can receive drip
     */
    function canDrip(address user) public view returns (bool) {
        uint256 currentDay = block.timestamp / 1 days;

        // Check cooldown
        if (block.timestamp < lastDripTime[user] + cooldownPeriod) {
            return false;
        }

        // Check daily limit
        uint256 todaysDrip = lastDripDay[user] == currentDay ? dailyDripAmount[user] : 0;
        if (todaysDrip + dripAmount > maxDailyLimit) {
            return false;
        }

        return true;
    }

    /**
     * @dev Get time until next drip is available
     */
    function timeUntilNextDrip(address user) external view returns (uint256) {
        if (canDrip(user)) {
            return 0;
        }

        uint256 nextDripTime = lastDripTime[user] + cooldownPeriod;
        if (block.timestamp >= nextDripTime) {
            return 0;
        }

        return nextDripTime - block.timestamp;
    }

    /**
     * @dev Get remaining daily limit for address
     */
    function remainingDailyLimit(address user) external view returns (uint256) {
        uint256 currentDay = block.timestamp / 1 days;
        uint256 todaysDrip = lastDripDay[user] == currentDay ? dailyDripAmount[user] : 0;

        if (todaysDrip >= maxDailyLimit) {
            return 0;
        }

        return maxDailyLimit - todaysDrip;
    }

    /**
     * @dev Update faucet configuration
     */
    function updateConfig(
        uint256 _dripAmount,
        uint256 _cooldownPeriod,
        uint256 _maxDailyLimit
    ) external onlyOwner {
        require(_dripAmount > 0, "Drip amount must be positive");
        require(_cooldownPeriod > 0, "Cooldown must be positive");
        require(_maxDailyLimit >= _dripAmount, "Daily limit must be >= drip amount");

        dripAmount = _dripAmount;
        cooldownPeriod = _cooldownPeriod;
        maxDailyLimit = _maxDailyLimit;

        emit ConfigUpdate(_dripAmount, _cooldownPeriod, _maxDailyLimit);
    }

    /**
     * @dev Refill faucet with tokens
     */
    function refill(uint256 amount) external {
        require(
            aiToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        emit FaucetRefill(amount);
    }

    /**
     * @dev Get faucet balance
     */
    function balance() external view returns (uint256) {
        return aiToken.balanceOf(address(this));
    }

    /**
     * @dev Emergency withdraw (owner only)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).transfer(owner(), amount);
        }

        emit EmergencyWithdraw(token, amount);
    }

    /**
     * @dev Pause faucet
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause faucet
     */
    function unpause() external onlyOwner {
        _unpause();
    }
}
