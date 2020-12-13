// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../openzeppelin/token/HRC20/IHRC20.sol";
import "../openzeppelin/token/HRC20/SafeHRC20.sol";
import "../openzeppelin/utils/EnumerableSet.sol";
import "../openzeppelin/math/SafeMath.sol";
import "../openzeppelin/access/Ownable.sol";
import "../snowball/Snowball.sol";

// Farm is the generator of Snowball. He can make Snowball and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Snowball is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Farm is Ownable {
    using SafeMath for uint256;
    using SafeHRC20 for IHRC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Snowballs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accSnowballPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accSnowballPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IHRC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. Snowball to distribute per block.
        uint256 lastRewardBlock;  // Last block number that Snowball distribution occurs.
        uint256 accSnowballPerShare; // Accumulated Snowball per share, times 1e12. See below.
    }

    // The Snowball TOKEN!
    Snowball public snowball;
    // Dev address.
    address public devaddr;
    // Block number when bonus Snowball period ends.
    uint256 public bonusEndBlock;
    // Snowball tokens created per block.
    uint256 public snowballPerBlock;
    // Bonus muliplier for early snowball makers.
    uint256 public constant BONUS_MULTIPLIER = 10;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when Snowball mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    //f279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        Snowball _snowball,
        address _devaddr,
        uint256 _snowballPerBlock,
        uint256 _startBlock,
        uint256 _bonusEndBlock
    ) {
        snowball = _snowball;
        devaddr = _devaddr;
        snowballPerBlock = _snowballPerBlock;
        bonusEndBlock = _bonusEndBlock;
        startBlock = _startBlock;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IHRC20 _lpToken, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
            lpToken: _lpToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accSnowballPerShare: 0
        }));
    }

    // Update the given pool's Snowball allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        if (_to <= bonusEndBlock) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else if (_from >= bonusEndBlock) {
            return _to.sub(_from);
        } else {
            return bonusEndBlock.sub(_from).mul(BONUS_MULTIPLIER).add(
                _to.sub(bonusEndBlock)
            );
        }
    }

    // View function to see pending Snowball on frontend.
    //pendingSnowBall
    function pendingReward(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accSnowballPerShare = pool.accSnowballPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 snowballReward = multiplier.mul(snowballPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accSnowballPerShare = accSnowballPerShare.add(snowballReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accSnowballPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 snowballReward = multiplier.mul(snowballPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        snowball.mint(devaddr, snowballReward.div(10));
        snowball.mint(address(this), snowballReward);
        pool.accSnowballPerShare = pool.accSnowballPerShare.add(snowballReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = block.number;
    }

    //e2bbb158ea830e9efa91fa2a38c9708f9f6109a6c571d6a762b53a83776a3d67
    // Deposit LP tokens to MasterChef for Snowball allocation.
    function deposit(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accSnowballPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeSnowballTransfer(msg.sender, pending);
            }
        }
        if(_amount > 0) {
            pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSnowballPerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    //441a3e70c6f476810f346a8a9bd493b00e9afd2ba1ab35eca9005dfd312435a9
    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accSnowballPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeSnowballTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accSnowballPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe Snowball transfer function, just in case if rounding error causes pool to not have enough Snowball.
    function safeSnowballTransfer(address _to, uint256 _amount) internal {
        uint256 snowballBalance = snowball.balanceOf(address(this));
        if (_amount > snowballBalance) {
            snowball.transfer(_to, snowballBalance);
        } else {
            snowball.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function dev(address _devaddr) public {
        require(msg.sender == devaddr, "dev: wut?");
        devaddr = _devaddr;
    }
}
