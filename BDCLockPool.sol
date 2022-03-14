// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

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
        uint256 value = available(to);
        upgradeLockedTokens[to].unlocked = value;
        lockedTotal += lock;
        upgradeLockedTokens[to].locked += lock;
        upgradeLockedTokens[to].lockedSnap = upgradeLockedTokens[to].locked;
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
                        .mul(dailyReleaseRate.mul(n).div(100))
                        .div(RATIO)
                        .mul(lastDay - decreaseDate[i])
                );
                if (i == 0) {
                    lastMinute = decreaseDate[i];
                }
            } else {
                value = value.add(
                    lockInfo
                        .lockedSnap
                        .mul(dailyReleaseRate.mul(i).div(100))
                        .div(RATIO)
                        .mul(lastDay - lockInfo.lastRewardDate)
                );
                break;
            }
        }
        if (!isDecrease) {
            lastMinute = currentDate();
        }
        if (lastMinute > 0) {
            value = value.add(
                lockInfo.lockedSnap.mul(dailyReleaseRate).div(RATIO).mul(
                    lastMinute - lockInfo.lastRewardDate
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

        withdrawTotal += value;
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
        lt.unlocked = lt.unlocked.add(value.mul(10).div(100));
        totalReferralRewards[referrer] = totalReferralRewards[referrer].add(
            value.mul(10).div(100)
        );
    }

    modifier checkRelease() {
        if (!isDecrease && lockedTotal.div(100) >= 1000000000000000000000000) {
            isDecrease = true;
        }

        if (
            isDecrease &&
            withdrawTotal / 3800000000000000000000000 > decreaseDate.length &&
            decreaseDate.length < 50
        ) {
            decreaseDate.push(currentDate());
        }
        _;
        if (!isDecrease && lockedTotal.div(100) >= 1000000000000000000000000) {
            isDecrease = true;
        }

        if (
            isDecrease &&
            withdrawTotal / 3800000000000000000000000 > decreaseDate.length &&
            decreaseDate.length < 50
        ) {
            decreaseDate.push(currentDate());
        }
    }

    function currentDate() public view returns (uint256) {
        return block.timestamp.div(1 hours);
    }
}
