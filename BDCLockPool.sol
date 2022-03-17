// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

import "./BDCToken.sol";

contract BDCLockPool {
    using SafeMath for uint256;

    uint256 public constant RATIO = 1e18;
    uint256 public dailyReleaseRate = (1 * RATIO) / 100;

    mapping(address => LockedToken) public upgradeLockedTokens;
    mapping(address => uint256) public totalWithdraw;
    mapping(address => uint256) public totalReferralRewards;
    uint256 public lockedTotal;
    uint256[] public decreaseDate;

    BDCToken public BDC;
    bool public isDecrease;
    uint256 public withdrawTotal;

    struct LockedToken {
        uint256 lockedSnap;
        uint256 locked;
        uint256 lastRewardDate;
        uint256 unlocked;
    }

    event Locking(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);

    constructor(BDCToken BDC_) {
        BDC = BDC_;
    }

    function reduceRate() public view returns (uint256) {
        return decreaseDate.length;
    }

    function lockToken(address to, uint256 lock) external checkRelease {
        require(lock > 0, "lock is zero");
        uint256 value = available(to);
        upgradeLockedTokens[to].unlocked = value;
        upgradeLockedTokens[to].locked = upgradeLockedTokens[to].locked.add(
            lock
        );
        lockedTotal = lockedTotal.sub(upgradeLockedTokens[to].lockedSnap);
        upgradeLockedTokens[to].lockedSnap = upgradeLockedTokens[to].locked;
        lockedTotal = lockedTotal.add(upgradeLockedTokens[to].lockedSnap);
        upgradeLockedTokens[to].lastRewardDate = currentDate();
        BDC.transferFrom(msg.sender, address(this), lock);
        emit Locking(to, lock);
    }

    function available(address account) public view returns (uint256) {
        LockedToken memory lockInfo = upgradeLockedTokens[account];
        uint256 value = lockInfo.unlocked;
        uint256 lastMinute = 0;
        for (uint256 n = decreaseDate.length; n > 0; n--) {
            uint256 i = n - 1;
            uint256 lastDay;
            if (n != decreaseDate.length) {
                lastDay = decreaseDate[n];
            } else {
                lastDay = currentDate();
            }
            if (lockInfo.lastRewardDate < decreaseDate[i]) {
                value = value.add(
                    lockInfo
                        .lockedSnap
                        .mul(dailyReleaseRate.mul(100 - n).div(100))
                        .div(RATIO)
                        .mul(lastDay.sub(decreaseDate[i]))
                );
                if (i == 0) {
                    lastMinute = decreaseDate[i];
                }
            } else {
                value = value.add(
                    lockInfo
                        .lockedSnap
                        .mul(dailyReleaseRate.mul(100 - n).div(100))
                        .div(RATIO)
                        .mul(lastDay.sub(lockInfo.lastRewardDate))
                );
                break;
            }
        }
        if (decreaseDate.length == 0) {
            lastMinute = currentDate();
        }
        if (lastMinute > 0) {
            value = value.add(
                lockInfo.lockedSnap.mul(dailyReleaseRate).div(RATIO).mul(
                    lastMinute.sub(lockInfo.lastRewardDate)
                )
            );
        }
        if (value > lockInfo.locked) {
            value = lockInfo.locked;
        }
        return value;
    }

    function withdraw() external checkRelease {
        LockedToken storage lt = upgradeLockedTokens[msg.sender];

        uint256 value = available(msg.sender);

        withdrawTotal = withdrawTotal.add(value);
        lt.locked = lt.locked.sub(value);
        lt.unlocked = 0;
        lt.lastRewardDate = currentDate();
        if (lt.locked == 0) {
            lockedTotal = lockedTotal.sub(lt.lockedSnap);
            lt.lockedSnap = 0;
        }
        totalWithdraw[msg.sender] = totalWithdraw[msg.sender].add(value);
        BDC.transfer(msg.sender, value);
        referralReward(msg.sender, value);
        emit Withdrawn(msg.sender, value);
    }

    function referralReward(address account, uint256 value) private {
        address referrer = BDC.referrers(account);
        if (referrer == address(0)) {
            return;
        }
        LockedToken storage lt = upgradeLockedTokens[referrer];
        uint256 reward = value.mul(10).div(100);
        uint256 _available = available(referrer);
        if (reward.add(_available) > lt.locked) {
            reward = lt.locked.sub(_available);
        }
        lt.unlocked = lt.unlocked.add(reward);
        totalReferralRewards[referrer] = totalReferralRewards[referrer].add(
            reward
        );
    }

    modifier checkRelease() {
        _;
        if (!isDecrease && lockedTotal.div(100) >= 150000 * 10**18) {
            isDecrease = true;
        }

        while (
            isDecrease &&
            withdrawTotal / (500000 * 10**18) > decreaseDate.length &&
            decreaseDate.length < 50
        ) {
            decreaseDate.push(currentDate());
        }
    }

    function currentDate() public view returns (uint256) {
        return block.timestamp.div(1 days);
    }
}
