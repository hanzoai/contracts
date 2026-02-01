// SPDX-License-Identifier: MIT
pragma solidity ^0.8.31;

import {ERC20, IERC20, IERC20Metadata} from "@luxfi/tokens/LRC20/LRC20.sol";
import {Ownable} from "@luxfi/access/Access.sol";
import {Pausable} from "@luxfi/utils/Utils.sol";

/**
 * @title AIToken
 * @author Hanzo AI
 * @notice Governance token for Hanzo AI ecosystem
 *
 * Features:
 * - Staking rewards distribution
 * - Deflationary burn mechanism
 * - Vesting schedules
 * - Pausable transfers
 */
contract AIToken is ERC20, Ownable, Pausable {
    // Token distribution
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens
    uint256 public constant TEAM_ALLOCATION = 150_000_000 * 10**18; // 15%
    uint256 public constant ECOSYSTEM_ALLOCATION = 350_000_000 * 10**18; // 35%
    uint256 public constant PUBLIC_SALE_ALLOCATION = 200_000_000 * 10**18; // 20%
    uint256 public constant LIQUIDITY_ALLOCATION = 100_000_000 * 10**18; // 10%
    uint256 public constant STAKING_REWARDS_ALLOCATION = 200_000_000 * 10**18; // 20%

    // Vesting
    struct VestingSchedule {
        uint256 totalAmount;
        uint256 startTime;
        uint256 cliffDuration;
        uint256 vestingDuration;
        uint256 amountClaimed;
        bool revokable;
        bool revoked;
    }

    mapping(address => VestingSchedule) public vestingSchedules;

    // Staking
    struct StakeInfo {
        uint256 amount;
        uint256 timestamp;
        uint256 rewards;
        uint256 lockPeriod; // 0, 30, 90, 180, 365 days
    }

    mapping(address => StakeInfo[]) public stakes;
    mapping(address => uint256) public totalStaked;
    uint256 public globalTotalStaked;

    // Reward rates based on lock period (basis points)
    mapping(uint256 => uint256) public rewardRates;

    // Fee mechanism
    uint256 public transferFeeRate = 0; // Can be activated by governance
    uint256 public burnRate = 10; // 0.1% burn on transfers
    uint256 public constant FEE_DENOMINATOR = 10000;
    address public treasuryAddress;

    // Events
    event VestingScheduleCreated(
        address indexed beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliff,
        uint256 duration
    );

    event TokensClaimed(address indexed beneficiary, uint256 amount);
    event VestingRevoked(address indexed beneficiary);

    event Staked(
        address indexed user,
        uint256 amount,
        uint256 lockPeriod,
        uint256 stakeIndex
    );

    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 rewards,
        uint256 stakeIndex
    );

    event RewardsClaimed(address indexed user, uint256 amount);

    constructor(
        address _treasuryAddress
    ) ERC20("AI Token", "AI") Ownable(msg.sender) {
        treasuryAddress = _treasuryAddress;

        // Initial minting
        _mint(msg.sender, TEAM_ALLOCATION);
        _mint(_treasuryAddress, ECOSYSTEM_ALLOCATION);
        _mint(address(this), STAKING_REWARDS_ALLOCATION); // For staking rewards

        // Set reward rates
        rewardRates[0] = 100;     // 1% APR for no lock
        rewardRates[30] = 300;    // 3% APR for 30 days
        rewardRates[90] = 600;    // 6% APR for 90 days
        rewardRates[180] = 1000;  // 10% APR for 180 days
        rewardRates[365] = 1500;  // 15% APR for 365 days
    }

    /**
     * @dev Create vesting schedule for an address
     */
    function createVestingSchedule(
        address beneficiary,
        uint256 amount,
        uint256 startTime,
        uint256 cliffDuration,
        uint256 vestingDuration,
        bool revokable
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary");
        require(amount > 0, "Invalid amount");
        require(vestingSchedules[beneficiary].totalAmount == 0, "Schedule exists");

        vestingSchedules[beneficiary] = VestingSchedule({
            totalAmount: amount,
            startTime: startTime,
            cliffDuration: cliffDuration,
            vestingDuration: vestingDuration,
            amountClaimed: 0,
            revokable: revokable,
            revoked: false
        });

        // Transfer tokens to this contract for vesting
        _transfer(msg.sender, address(this), amount);

        emit VestingScheduleCreated(
            beneficiary,
            amount,
            startTime,
            cliffDuration,
            vestingDuration
        );
    }

    /**
     * @dev Claim vested tokens
     */
    function claimVestedTokens() external {
        VestingSchedule storage schedule = vestingSchedules[msg.sender];
        require(schedule.totalAmount > 0, "No vesting schedule");
        require(!schedule.revoked, "Vesting revoked");

        uint256 claimable = _calculateVestedAmount(msg.sender) - schedule.amountClaimed;
        require(claimable > 0, "Nothing to claim");

        schedule.amountClaimed += claimable;
        _transfer(address(this), msg.sender, claimable);

        emit TokensClaimed(msg.sender, claimable);
    }

    /**
     * @dev Stake tokens with optional lock period
     */
    function stake(uint256 amount, uint256 lockPeriod) external whenNotPaused {
        require(amount > 0, "Invalid amount");
        require(
            lockPeriod == 0 || lockPeriod == 30 || lockPeriod == 90 ||
            lockPeriod == 180 || lockPeriod == 365,
            "Invalid lock period"
        );

        _transfer(msg.sender, address(this), amount);

        stakes[msg.sender].push(StakeInfo({
            amount: amount,
            timestamp: block.timestamp,
            rewards: 0,
            lockPeriod: lockPeriod
        }));

        totalStaked[msg.sender] += amount;
        globalTotalStaked += amount;

        emit Staked(msg.sender, amount, lockPeriod, stakes[msg.sender].length - 1);
    }

    /**
     * @dev Unstake tokens and claim rewards
     */
    function unstake(uint256 stakeIndex) external {
        require(stakeIndex < stakes[msg.sender].length, "Invalid index");

        StakeInfo storage stakeInfo = stakes[msg.sender][stakeIndex];
        require(stakeInfo.amount > 0, "Already unstaked");
        require(
            block.timestamp >= stakeInfo.timestamp + (stakeInfo.lockPeriod * 1 days),
            "Lock period not ended"
        );

        uint256 rewards = calculateRewards(msg.sender, stakeIndex);
        uint256 stakedAmount = stakeInfo.amount;
        uint256 totalAmount = stakedAmount + rewards;

        totalStaked[msg.sender] -= stakedAmount;
        globalTotalStaked -= stakedAmount;

        // Mark as unstaked
        stakeInfo.amount = 0;

        _transfer(address(this), msg.sender, totalAmount);

        emit Unstaked(msg.sender, stakedAmount, rewards, stakeIndex);
    }

    /**
     * @dev Calculate staking rewards
     */
    function calculateRewards(address user, uint256 stakeIndex)
        public
        view
        returns (uint256)
    {
        StakeInfo memory stakeInfo = stakes[user][stakeIndex];
        if (stakeInfo.amount == 0) return 0;

        uint256 duration = block.timestamp - stakeInfo.timestamp;
        uint256 rate = rewardRates[stakeInfo.lockPeriod];

        // Calculate rewards: amount * rate * duration / (365 days * FEE_DENOMINATOR)
        return (stakeInfo.amount * rate * duration) / (365 days * FEE_DENOMINATOR);
    }

    /**
     * @dev Calculate vested amount
     */
    function _calculateVestedAmount(address beneficiary)
        private
        view
        returns (uint256)
    {
        VestingSchedule memory schedule = vestingSchedules[beneficiary];

        if (block.timestamp < schedule.startTime + schedule.cliffDuration) {
            return 0;
        }

        if (block.timestamp >= schedule.startTime + schedule.vestingDuration) {
            return schedule.totalAmount;
        }

        uint256 elapsed = block.timestamp - schedule.startTime;
        return (schedule.totalAmount * elapsed) / schedule.vestingDuration;
    }

    /**
     * @dev Override _update to implement fees and pause
     */
    function _update(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        require(!paused(), "Token transfers paused");

        // Don't apply fees on mints, burns, or internal transfers
        if (from != address(0) && to != address(0) &&
            from != address(this) && to != address(this)) {

            uint256 burnAmount = 0;
            uint256 feeAmount = 0;

            if (burnRate > 0) {
                burnAmount = (amount * burnRate) / FEE_DENOMINATOR;
            }

            if (transferFeeRate > 0 && treasuryAddress != address(0)) {
                feeAmount = (amount * transferFeeRate) / FEE_DENOMINATOR;
            }

            uint256 transferAmount = amount - burnAmount - feeAmount;

            // Transfer the net amount
            super._update(from, to, transferAmount);

            // Burn
            if (burnAmount > 0) {
                super._update(from, address(0), burnAmount);
            }

            // Fee to treasury
            if (feeAmount > 0) {
                super._update(from, treasuryAddress, feeAmount);
            }
        } else {
            super._update(from, to, amount);
        }
    }

    /**
     * @dev Pause token transfers
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpause token transfers
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev Update fee rates (governance function)
     */
    function updateFeeRates(uint256 _transferFeeRate, uint256 _burnRate)
        external
        onlyOwner
    {
        require(_transferFeeRate <= 500, "Transfer fee too high"); // Max 5%
        require(_burnRate <= 100, "Burn rate too high"); // Max 1%

        transferFeeRate = _transferFeeRate;
        burnRate = _burnRate;
    }

    /**
     * @dev Update treasury address
     */
    function updateTreasury(address _treasuryAddress) external onlyOwner {
        require(_treasuryAddress != address(0), "Invalid address");
        treasuryAddress = _treasuryAddress;
    }

    /**
     * @dev Get all stakes for a user
     */
    function getUserStakes(address user)
        external
        view
        returns (StakeInfo[] memory)
    {
        return stakes[user];
    }

    /**
     * @dev Check if tokens are locked
     */
    function getLockedTokens(address user) external view returns (uint256) {
        uint256 locked = 0;

        // Add staked tokens
        locked += totalStaked[user];

        // Add unvested tokens
        VestingSchedule memory schedule = vestingSchedules[user];
        if (schedule.totalAmount > 0 && !schedule.revoked) {
            locked += schedule.totalAmount - schedule.amountClaimed;
        }

        return locked;
    }
}
