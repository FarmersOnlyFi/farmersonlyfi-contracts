// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IAdenaChef {
  function MAXIMUM_DEPOSIT_FEE_RATE (  ) external view returns ( uint16 );
  function MAXIMUM_HARVEST_INTERVAL (  ) external view returns ( uint256 );
  function canHarvest ( uint256 _pid, address _user ) external view returns ( bool );
  function deposit ( uint256 _pid, uint256 _amount ) external;
  function emergencyWithdraw ( uint256 _pid ) external;
  function pendingAdena ( uint256 _pid, address _user ) external view returns ( uint256 );
  function poolInfo ( uint256 ) external view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accAdenaPerShare, uint16 depositFeeBP, uint256 harvestInterval, uint256 totalLp );
  function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt, uint256 rewardLockedUp, uint256 nextHarvestUntil );
  function withdraw ( uint256 _pid, uint256 _amount ) external;
}
