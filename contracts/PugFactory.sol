// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./Pug.sol";
import "./IPugToken.sol";
import "./IPugStaking.sol";

interface SushiFactory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract PugFactory is Ownable {

    mapping(address => uint256) public rewardPoints;
    mapping(address => address) public pugPool;
    uint256 public totalRewardPoints;

    address public pugToken;
    address pugStaking;
    address sushiFactory;
    address sushiRouter;
    address WETH;

    uint256 public rewardsPerSecond;
    uint256 public pugCreationReward;
    uint256 public fee;
    uint256 public rewardEndTime;

    event PugCreated(address indexed pug, string name, string indexed symbol, address indexed baseToken, uint256 decimals);
    event RewardPointsUpdated(address indexed token, uint256 tokenRewardPoints, uint256 currentTotalRewardPoints);
    event AddToWhitelist(address indexed token, uint256 tokenRewardPoints, uint256 currentTotalRewardPoints);
    event RemoveFromWhitelist(address indexed token, uint256 tokenRewardPoints, uint256 currentTotalRewardPoints);
    event PugTokenUpdated(address indexed updatedPugToken);
    event PugCreationRewardUpdated(uint256 updatePugCreationReward);
    event RewardsPerSecondUpdated(uint256 updatedRewardsPerSecond);
    event FeeUpdated(uint256 updatedFee);
    event PugStakingUpdated(address indexed updatedPugStaking);
    event SushiFactoryUpdated(address updatedSushiFactory);
    event SushiRouterUpdated(address updatedSushiRouter);
    event WETHUpdated(address updatedWETH);

    constructor(
        address _admin, 
        address _pugToken, 
        uint256 _pugCreationReward, 
        uint256 _fee, 
        uint256 _rewardsPerSecond, 
        address _pugStaking, 
        address _sushiFactory,
        address _sushiRouter,
        address _WETH
    ) Ownable() {
        transferOwnership(_admin);
        pugToken = _pugToken;
        emit PugTokenUpdated(_pugToken);
        pugCreationReward = _pugCreationReward;
        emit PugCreationRewardUpdated(_pugCreationReward);
        fee = _fee;
        emit FeeUpdated(_fee);
        rewardsPerSecond = _rewardsPerSecond;
        emit RewardsPerSecondUpdated(_rewardsPerSecond);
        pugStaking = _pugStaking;
        sushiFactory = _sushiFactory;
        sushiRouter = _sushiRouter;
        WETH = _WETH;
        rewardEndTime = block.timestamp + 14 days;
    }

    function createPug(string memory _name, string memory _symbol, address _baseToken, uint256 _decimals) external {
        require(pugPool[_baseToken] == address(0), "Pug already exists for baseToken");
        require(
            SushiFactory(sushiFactory).getPair(_baseToken, WETH) != address(0),
            "BaseToken WETH pair necessary to create Pug"
        );
        address _pugToken = pugToken;
        Pug createdPug = new Pug(_name, 
            _symbol,
            _baseToken,
            _pugToken, 
            _decimals,  
            fee, 
            owner(),
            pugStaking,
            sushiRouter,
            WETH
        );
        pugPool[_baseToken] = address(createdPug);
        IPugStaking(pugStaking).addPug(_baseToken, address(createdPug));
        emit PugCreated(address(createdPug), _name, _symbol, _baseToken, _decimals);
        if(rewardPoints[_baseToken] != 0) {
            IPugToken(_pugToken).mint(msg.sender, pugCreationReward);
        }
    }

    function claimRewards(uint256 _lastRewardTime, address _baseToken) external returns(uint256) {
        require(pugPool[_baseToken] == msg.sender, "Only pug can claim rewards");
        uint256 allocatedReward = getRewardsPerSecond(_baseToken);
        uint256 reward = (block.timestamp - _lastRewardTime) * allocatedReward;
        if(reward != 0) {
            IPugToken(pugToken).mint(msg.sender, reward);
        }
        return reward;
    }

    function getRewardsPerSecond(address baseToken) view public returns(uint256) {
        if(block.timestamp > rewardEndTime) {
            return 0;
        }
        uint256 _totalRewardPoints = totalRewardPoints;
        return (_totalRewardPoints != 0 ? (rewardPoints[baseToken] * rewardsPerSecond / _totalRewardPoints): 0);
    }

    function updatePugToken(address _newPugTokenAddress) external onlyOwner {
        pugToken = _newPugTokenAddress;
        emit PugTokenUpdated(_newPugTokenAddress);
    }

    function updateRewardPerSecond(uint256 _updatedRewards) external onlyOwner {
        rewardsPerSecond = _updatedRewards;
        emit RewardsPerSecondUpdated(_updatedRewards);
    }

    function updatePugCreationReward(uint256 _updatedReward) external onlyOwner {
        pugCreationReward = _updatedReward;
        emit PugCreationRewardUpdated(_updatedReward);
    }

    function updateFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function updatePugStaking(address _newPugStaking) external onlyOwner {
        pugStaking = _newPugStaking;
        emit PugStakingUpdated(_newPugStaking);
    }

    function updateSushiFactory(address _updatedSushiFactory) external onlyOwner {
        sushiFactory = _updatedSushiFactory;
        emit SushiFactoryUpdated(_updatedSushiFactory);
    }

    function updateSushiRouter(address _updatedSushiRouter) external onlyOwner {
        sushiRouter = _updatedSushiRouter;
        emit SushiRouterUpdated(_updatedSushiRouter);
    }

    function updateWETH(address _updatedWETH) external onlyOwner {
        WETH = _updatedWETH;
        emit WETHUpdated(_updatedWETH);
    }

    function updateRewardPoints(address _token, uint256 _rewardPoints) external onlyOwner {
        uint256 tokenRewardPoints = rewardPoints[_token];
        rewardPoints[_token] = _rewardPoints;
        uint256 currentTotalRewardPoints = totalRewardPoints - tokenRewardPoints + _rewardPoints;
        totalRewardPoints = currentTotalRewardPoints;
        emit RewardPointsUpdated(_token, _rewardPoints, currentTotalRewardPoints);
    }
}