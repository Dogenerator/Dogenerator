// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPugFactory {
    function claimRewards(uint256 _lastRewardTime, address _baseToken) external returns(uint256);
}