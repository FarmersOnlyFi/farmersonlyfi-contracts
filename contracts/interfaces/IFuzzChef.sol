// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IFuzzChef {
    function deposit ( uint256 _pid, uint256 _amount ) external;
    function emergencyWithdraw ( uint256 _pid ) external;
    function enterStaking ( uint256 _amount ) external;
    function fuzz (  ) external view returns ( address );
    function fuzzPerBlock (  ) external view returns ( uint256 );
    function getBlock (  ) external view returns ( uint256 );
    function getMultiplier ( uint256 _from, uint256 _to ) external view returns ( uint256 );
    function getStakingMultiplier ( address _user ) external view returns ( uint256 );
    function isStaked ( address _user ) external view returns ( bool );
    function leaveStaking ( uint256 _amount ) external;
    function pendingFuzz ( uint256 _pid, address _user ) external view returns ( uint256 );
    function pendingStakingRewards ( uint256 _pid, address _user ) external view returns ( uint256 );
    function poolInfo ( uint256 ) external view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accFuzzPerShare );
    function poolLength (  ) external view returns ( uint256 );
    function stakingRewardActive (  ) external view returns ( bool );
    function startBlock (  ) external view returns ( uint256 );
    function totalAllocPoint (  ) external view returns ( uint256 );
    function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt, uint256 lastPendingFuzz );
    function withdraw ( uint256 _pid, uint256 _amount ) external;
}
