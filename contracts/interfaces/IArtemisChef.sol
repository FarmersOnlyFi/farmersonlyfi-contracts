// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IArtemisChef {
  function BONUS_MULTIPLIER (  ) external view returns ( uint256 );
  function add ( uint256 _allocPoint, address _lpToken, uint16 _depositFeeBP, bool _withUpdate ) external;
  function deposit ( uint256 _pid, uint256 _amount, address _to ) external;
  function dev ( address _devaddr ) external;
  function devaddr (  ) external view returns ( address );
  function emergencyWithdraw ( uint256 _pid ) external;
  function feeAddress (  ) external view returns ( address );
  function getMultiplier ( uint256 _from, uint256 _to ) external view returns ( uint256 );
  function labo (  ) external view returns ( address );
  function laboPerBlock (  ) external view returns ( uint256 );
  function massUpdatePools (  ) external;
  function owner (  ) external view returns ( address );
  function pendingLabo ( uint256 _pid, address _user ) external view returns ( uint256 );
  function poolExistence ( address ) external view returns ( bool );
  function poolInfo ( uint256 ) external view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accLaboPerShare, uint16 depositFeeBP );
  function poolLength (  ) external view returns ( uint256 );
  function renounceOwnership (  ) external;
  function set ( uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, bool _withUpdate ) external;
  function setFeeAddress ( address _feeAddress ) external;
  function setStartBlock ( uint256 _startBlock ) external;
  function startBlock (  ) external view returns ( uint256 );
  function totalAllocPoint (  ) external view returns ( uint256 );
  function transferOwnership ( address newOwner ) external;
  function updateEmissionRate ( uint256 _laboPerBlock ) external;
  function updatePool ( uint256 _pid ) external;
  function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt );
  function withdraw ( uint256 _pid, uint256 _amount ) external;
}
