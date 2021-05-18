// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./IPugFactory.sol";
import "./IPugStaking.sol";

interface SushiRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

contract Pug is ERC20PresetMinterPauser, Ownable {
    using SafeERC20 for ERC20;

    address pugFactory;
    address public baseToken;
    address pugToken;
    address public pugStaking;

    uint256 public pugRatio; // pugToken per native token
    uint256 public fee; // per 10^12

    uint256 lastRewardTime;
    uint256 accPugTokenPerShare;
    mapping(address => uint256) userDebt;

    uint8 DECIMALS;
    address sushiRouter;
    address WETH;

    uint256 constant DENOMINATION = 1e12;
    uint256 constant INFINITY = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    event RewardsWithdrawn(address to, uint256 amount);
    event PugTokenUpdated(address indexed updatedPugToken);
    event PugFactoryUpdated(address indexed updatedFactoryToken);
    event FeeUpdated(uint256 updatedFee);
    event PugStakingUpdated(address indexed updatedPugStaking);
    event SushiRouterUpdated(address updatedSushiRouter);
    event WETHUpdated(address updatedWETH);

    constructor(
        string memory _name, 
        string memory _symbol,
        address _baseToken,
        address _pugToken, 
        uint256 _decimals, 
        uint256 _fee, 
        address _owner,
        address _pugStaking,
        address _sushiRouter,
        address _WETH
    ) ERC20PresetMinterPauser(_name, _symbol) Ownable() {
        baseToken = _baseToken;
        pugToken = _pugToken;
        emit PugTokenUpdated(_pugToken);
        pugStaking = _pugStaking;
        emit PugStakingUpdated(_pugStaking);
        fee = _fee;
        emit FeeUpdated(_fee);
        
        DECIMALS = uint8(_decimals);
        pugRatio = 10**(uint256(ERC20(_baseToken).decimals()) - _decimals);

        transferOwnership(_owner);
        pugFactory = msg.sender;
        emit PugFactoryUpdated(msg.sender);

        lastRewardTime = block.timestamp;
        renounceRole(MINTER_ROLE, msg.sender);

        IERC20(_baseToken).approve(sushiRouter, INFINITY);
        sushiRouter = _sushiRouter;
        WETH = _WETH;
    }

    function decimals() public view virtual override returns (uint8) {
        return DECIMALS;
    }

    function updateRewards() public {
        uint256 _lastRewardTime = lastRewardTime;
        if(block.timestamp <= _lastRewardTime) {
            return;
        }
        uint256 pugSupply = totalSupply();
        if(pugSupply == 0) {
            lastRewardTime = block.timestamp;
            return;
        }
        uint256 reward = getPugRewards(_lastRewardTime);
        accPugTokenPerShare = accPugTokenPerShare + (reward * DENOMINATION / pugSupply);
        lastRewardTime = block.timestamp;
    }

    function getPugRewards(uint256 _lastRewardTime) internal returns(uint256) {
        return IPugFactory(pugFactory).claimRewards(_lastRewardTime, baseToken);
    }

    function pug(uint256 _amount) external {
        uint256 senderBalance = balanceOf(msg.sender);
        updateRewards();
        if(senderBalance != 0) {
            uint256 pendingRewards = (senderBalance * accPugTokenPerShare / DENOMINATION) - userDebt[msg.sender];
            transferRewards(msg.sender, pendingRewards);
        }
        address _baseToken = baseToken;
        uint256 feeAmount = _amount * fee / 2 / DENOMINATION;

        ERC20(_baseToken).transferFrom(msg.sender, address(this), _amount);
        try ERC20PresetMinterPauser(_baseToken).burn(feeAmount) {

        } catch (bytes memory) {
            try ERC20(_baseToken).transfer(address(0), feeAmount) {
                
            } catch (bytes memory) {
                feeAmount = feeAmount * 2;
            }
        }
        address _pugStaking = pugStaking;
        uint256 feeInPugToken = swapForPugAndSend(feeAmount, _pugStaking);
        IPugStaking(_pugStaking).addRewards(feeInPugToken);

        _mint(msg.sender, _amount);
        userDebt[msg.sender] = (senderBalance + _amount) * accPugTokenPerShare / DENOMINATION;
    }

    function swapForPugAndSend(uint256 _fee, address _to) internal returns(uint256) {
        address[] memory path;
        path[0]= baseToken;
        path[1] = WETH;
        path[2] = pugToken;
        uint[] memory amounts = SushiRouter(sushiRouter).swapExactTokensForTokens(
            _fee, 
            1, 
            path,
            _to,
            block.timestamp + 100
        );
        return amounts[amounts.length - 1];
    }

    function unpug(uint256 _amount) external {
        uint256 senderBalance = balanceOf(msg.sender);
        updateRewards();
        require(senderBalance >= _amount, "Balance not enough");
        uint256 pendingRewards = (senderBalance * accPugTokenPerShare / DENOMINATION) - userDebt[msg.sender];
        transferRewards(msg.sender, pendingRewards);
        
        address _baseToken = baseToken;
        userDebt[msg.sender] = (senderBalance - _amount) * accPugTokenPerShare / DENOMINATION;
        uint256 totalBaseTokensHeld = ERC20(_baseToken).balanceOf(address(this));
        uint256 baseTokenValue = _amount * totalBaseTokensHeld / totalSupply();
        _burn(msg.sender, _amount);
        ERC20(_baseToken).transfer(msg.sender, baseTokenValue);
    }

    function withdrawRewards(address _user) external returns(uint256) {
        updateRewards();
        uint256 balance = balanceOf(_user);
        uint256 totalReward = balance * accPugTokenPerShare / DENOMINATION;
        uint256 pendingRewards = totalReward - userDebt[_user];
        transferRewards(_user, pendingRewards);
        userDebt[_user] = totalReward;
        return pendingRewards;
    }

    function transferRewards(address _to, uint256 _amount) internal {
        if(_amount == 0) {
            return;
        }
        uint256 rewardsLeft = ERC20(pugToken).balanceOf(address(this));
        if(_amount > rewardsLeft) {
            ERC20(pugToken).transfer(_to, rewardsLeft);
        } else {
            ERC20(pugToken).transfer(_to, _amount);
        }
        emit RewardsWithdrawn(_to, _amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20PresetMinterPauser) {
        updateRewards();
        uint256 currentAccPugTokenPerShare = accPugTokenPerShare;

        if(from != address(0)) {
            uint256 fromBalance = balanceOf(from);
            uint256 fromPendingRewards = fromBalance * currentAccPugTokenPerShare / DENOMINATION - userDebt[from];
            userDebt[from] = (fromBalance - amount) * currentAccPugTokenPerShare / DENOMINATION;
            transferRewards(msg.sender, fromPendingRewards);
        }
        
        if(to != address(0)) {
            uint256 toBalance = balanceOf(to);
            uint256 toPendingRewards = toBalance * currentAccPugTokenPerShare / DENOMINATION - userDebt[to];
            userDebt[to] = (toBalance + amount) * currentAccPugTokenPerShare / DENOMINATION;
            transferRewards(msg.sender, toPendingRewards);
        }
    }

    function updatePugToken(address _newPugTokenAddress) external onlyOwner {
        pugToken = _newPugTokenAddress;
        emit PugTokenUpdated(_newPugTokenAddress);
    }

    function updatePugFactory(address _newPugFactoryAddress) external onlyOwner {
        pugFactory = _newPugFactoryAddress;
        emit PugFactoryUpdated(_newPugFactoryAddress);
    }

    function updatePugStaking(address _newPugStaking) external onlyOwner {
        pugStaking = _newPugStaking;
        emit PugStakingUpdated(_newPugStaking);
    }

    function updateFee(uint256 _fee) external onlyOwner {
        fee = _fee;
        emit FeeUpdated(_fee);
    }

    function updateSushiRouter(address _updatedSushiRouter) external onlyOwner {
        sushiRouter = _updatedSushiRouter;
        emit SushiRouterUpdated(_updatedSushiRouter);
    }

    function updateWETH(address _updatedWETH) external onlyOwner {
        WETH = _updatedWETH;
        emit WETHUpdated(_updatedWETH);
    }
}