// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "OpenZeppelin/openzeppelin-contracts@3.1.0/contracts/access/Ownable.sol";
import "OpenZeppelin/openzeppelin-contracts@3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "OpenZeppelin/openzeppelin-contracts@3.1.0/contracts/utils/EnumerableSet.sol";
import "OpenZeppelin/openzeppelin-contracts@3.1.0/contracts/utils/ReentrancyGuard.sol";

import "./Vault2/Operators.sol";

contract MockSushiChef is Ownable, ReentrancyGuard, Operators {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;
        int256 rewardDebt;
    }

    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. SUSHIs to distribute per block.
        uint256 lastRewardBlock; // Last block number that SUSHIs distribution occurs.
        uint256 accSushiPerShare; // Accumulated SUSHIs per share, times 1e12. See below.
    }
    IERC20 public sushi;
    IERC20 public WONE;
    uint256 public totalAllocPoint = 0;
    // The block number when SUSHI mining starts.
    uint256 public startBlock;
    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    mapping(address => bool) private strats;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount, address indexed to);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, address indexed to);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IERC20 _sushi,
        IERC20 _wone
    ) public {
        sushi = _sushi;
        WONE = _wone;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @dev Add a new want to the pool. Can only be called by the owner.
     */
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken
    ) public onlyOwner {
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accSushiPerShare: 0
            })
        );
    }

    function deposit(uint256 _pid, uint256 _amount, address _to) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount.add(_amount);
        emit Deposit(address(msg.sender), _pid, _amount, _to);
    }

    function harvest(uint256 pid, address to) public {
        // Just transfer 100 sushi and 100 WONE
        sushi.safeTransfer(to, 100);
        WONE.transfer(to, 100);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount, address _to) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(_to, _amount);
        emit Withdraw(msg.sender, _pid, _amount, _to);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid, address _to) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.lpToken.safeTransfer(_to, user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, _to);
        user.amount = 0;
        user.rewardDebt = 0;
    }

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
        pool.lastRewardBlock = block.number;
    }

}