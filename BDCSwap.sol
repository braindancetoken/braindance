// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./BDCToken.sol";
import "./BDCLockPool.sol";

contract BDCSwap is Ownable {
    using SafeMath for uint256;

    IERC20 public bdcToken;
    IERC20 public bdToken;
    BDCLockPool public lockTokenPool;
    uint256 public totalSupplyBD;
    uint256 public totalSupplyBDC;
    mapping(address => uint256) public bdcTokenBurn;
    mapping(address => uint256) public bdTokenBurn;
    address public constant hole = 0x000000000000000000000000000000000000dEaD;

    constructor(IERC20 bdcToken_, IERC20 bdToken_) {
        bdcToken = bdcToken_;
        bdToken = bdToken_;
    }

    function setLockTokenPool(BDCLockPool lockTokenPool_) external onlyOwner {
        lockTokenPool = lockTokenPool_;
    }

    function swapBD(uint256 value) external {
        require(
            bdToken.balanceOf(address(this)) >= value,
            "isufficient BD reserves"
        );
        totalSupplyBD += value;
        bdcTokenBurn[msg.sender] += value;
        bdcToken.transferFrom(msg.sender, hole, value);
        bdToken.transfer(msg.sender, value);
    }

    function swapBDC(uint256 bdValue) external {
        require(
            address(lockTokenPool) != address(0),
            "lock cnotract is zero address"
        );
        require(bdValue >= 10000000000000000000000, "bd too low");
        bdToken.transferFrom(msg.sender, hole, bdValue);
        uint256 mintValue = bdValue.mul(3);
        require(
            bdcToken.balanceOf(address(this)) >= mintValue,
            "isufficient BDC reserves"
        );
        totalSupplyBDC += mintValue;
        bdTokenBurn[msg.sender] = bdTokenBurn[msg.sender].add(bdValue);
        bdcToken.approve(address(lockTokenPool), mintValue);
        lockTokenPool.lockToken(msg.sender, mintValue);
    }
}
