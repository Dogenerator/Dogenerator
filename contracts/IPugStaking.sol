// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IPugStaking {
    function addRewards(uint256 _amount) external;
    function addPug(address _baseToken, address _pug) external;
}