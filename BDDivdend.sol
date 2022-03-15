// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BDDivdend is Ownable {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    IERC20 public BDToken;
    IERC20 public BDPair;
    address public treasury;

    uint256 public startAmount;
    uint256 public divdendCount;

    mapping(uint256 => uint256) private totalPower;
    mapping(address => uint256) public balances;
    mapping(uint256 => mapping(address => bool)) public isReward;
    mapping(address => uint256) public pairRewardTotal;
    uint256 public totalStaked;

    uint256 public divdendAmount = 1000000 * 10**18;
    uint256 public stakeEndTime;
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);

    constructor(
        IERC20 BDToken_,
        IERC20 BDPair_,
        address treasury_
    ) {
        BDToken = BDToken_;
        BDPair = BDPair_;
        treasury = treasury_;
        startAmount = BDToken.balanceOf(address(BDToken));
    }

    function possible() public view returns (bool) {
        uint256 newBalance = BDToken.balanceOf(address(BDToken));
        if (newBalance <= startAmount) {
            return false;
        }
        uint256 count = (
            newBalance.sub(startAmount).div(divdendAmount.mul(10))
        );
        if (count > divdendCount) {
            return true;
        }
        return false;
    }

    function executeDivdend() external onlyOwner {
        require(possible(), "insufficient progress");
        divdendCount += 1;
        stakeEndTime = block.timestamp.add(2 days).div(1 days).mul(1 days);
        BDToken.safeTransferFrom(treasury, address(this), divdendAmount);
    }

    function stake(uint256 value) external {
        require(block.timestamp < stakeEndTime, "staked has expired");
        BDPair.safeTransferFrom(msg.sender, address(this), value);
        balances[msg.sender] = balances[msg.sender].add(value);
        totalStaked = totalStaked.add(value);
        emit Staked(msg.sender, value);
    }

    function withdraw(uint256 value) external updateData {
        require(block.timestamp > stakeEndTime, "locked");
        getReward();
        if (value > 0) {
            balances[msg.sender] = balances[msg.sender].sub(value);
            totalStaked = totalStaked.sub(value);
            BDPair.safeTransfer(msg.sender, value);
            emit Withdrawn(msg.sender, value);
        }
    }

    function pairReward(address account) public view returns (uint256) {
        uint256 _totalPower = totalPower[divdendCount];
        if (_totalPower == 0) {
            _totalPower = totalStaked;
        }
        if (_totalPower == 0 || isReward[divdendCount][account]) {
            return 0;
        }
        return divdendAmount.mul(balances[account]).div(_totalPower);
    }

    function getReward() public updateData {
        require(block.timestamp > stakeEndTime, "locked");
        uint256 reward = pairReward(msg.sender);
        if (reward > 0) {
            pairRewardTotal[msg.sender] = pairRewardTotal[msg.sender].add(
                reward
            );
            isReward[divdendCount][msg.sender] = true;
            BDToken.safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    modifier updateData() {
        if (totalPower[divdendCount] == 0 && divdendCount > 0) {
            totalPower[divdendCount] = totalStaked;
        }
        _;
    }
}
