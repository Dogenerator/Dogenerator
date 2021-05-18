// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PugStaking {
    using SafeERC20 for IERC20;
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    mapping(address => UserInfo) public userStakingInfo;
    uint256 totalStaked;
    uint256 accRewardPerShare;
    mapping(address => address) baseTokens;

    address pugToken;
    address pugFactory;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event RewardWithdrawn(address indexed user, uint256 amount);

    modifier onlyPugFactory {
        require(msg.sender == pugFactory, "Not pug factory");
        _;
    }

    constructor(address _pugToken, address _pugFactory) {
        pugToken = _pugToken;
        pugFactory = _pugFactory;
    }

    function addPug(address _baseToken, address _pug) public onlyPugFactory {
        baseTokens[_pug] = _baseToken;
    }

    function addRewards(uint256 _amount) public {
        require(baseTokens[msg.sender] != address(0), "Not a pug");
        if(totalStaked != 0) {
            accRewardPerShare += _amount * 1e12 / totalStaked;
        }
    }

    function deposit(uint256 _amount) external {
        UserInfo memory stakingInfo = userStakingInfo[msg.sender];
        uint256 _accRewardPerShare = accRewardPerShare;
        if(stakingInfo.amount != 0) {
            uint256 pendingReward = (_accRewardPerShare * stakingInfo.amount / 1e12) - stakingInfo.rewardDebt;
            transferRewards(msg.sender, pendingReward);
        }
        IERC20(pugToken).transferFrom(msg.sender, address(this), _amount);
        uint256 userDeposit = stakingInfo.amount + _amount;
        userStakingInfo[msg.sender] = UserInfo(userDeposit, userDeposit * _accRewardPerShare / 1e12);
        totalStaked += _amount;
        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external {
        UserInfo memory stakingInfo = userStakingInfo[msg.sender];
        uint256 _accRewardPerShare = accRewardPerShare;
        uint256 pendingReward = (_accRewardPerShare * stakingInfo.amount / 1e12) - stakingInfo.rewardDebt;
        transferRewards(msg.sender, pendingReward);
        uint256 userDeposit = stakingInfo.amount - _amount;
        userStakingInfo[msg.sender] = UserInfo(userDeposit, userDeposit * _accRewardPerShare / 1e12);
        totalStaked -= _amount;
        IERC20(pugToken).transfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    function withdrawRewards(address _user) external {
        UserInfo memory stakingInfo = userStakingInfo[_user];
        uint256 _accRewardPerShare = accRewardPerShare;
        uint256 pendingReward = (_accRewardPerShare * stakingInfo.amount / 1e12) - stakingInfo.rewardDebt;
        userStakingInfo[_user].rewardDebt = stakingInfo.amount * _accRewardPerShare / 1e12;
        transferRewards(_user, pendingReward);
    }

    function transferRewards(address to, uint256 amount) internal {
        if(amount == 0) {
            return;
        }
        address _pugToken = pugToken;
        uint256 balance = IERC20(_pugToken).balanceOf(address(this));
        uint256 toTransfer;
        if(amount > balance) {
            toTransfer = balance;
        } else {
            toTransfer = amount;
        }
        IERC20(_pugToken).transfer(to, toTransfer);
        emit RewardWithdrawn(to, toTransfer);
    }
}