// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IPiggyChef {
    function BONUS_MULTIPLIER (  ) external view returns ( uint256 );
    function MAXIMUM_HARVEST_INTERVAL (  ) external view returns ( uint256 );
    function MAXIMUM_REFERRAL_COMMISSION_RATE (  ) external view returns ( uint16 );
    function add ( uint256 _allocPoint, address _lpToken, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate ) external;
    function canHarvest ( uint256 _pid, address _user ) external view returns ( bool );
    function deposit ( uint256 _pid, uint256 _amount, address _referrer ) external;
    function dev ( address _devaddr ) external;
    function devaddr (  ) external view returns ( address );
    function emergencyWithdraw ( uint256 _pid ) external;
    function feeAddress (  ) external view returns ( address );
    function getMultiplier ( uint256 _from, uint256 _to ) external pure returns ( uint256 );
    function massUpdatePools (  ) external;
    function owner (  ) external view returns ( address );
    function pendingCoink ( uint256 _pid, address _user ) external view returns ( uint256 );
    function poolInfo ( uint256 ) external view returns ( address lpToken, uint256 allocPoint, uint256 lastRewardBlock, uint256 accCoinkPerShare, uint16 depositFeeBP, uint256 harvestInterval );
    function poolLength (  ) external view returns ( uint256 );
    function referralCommissionRate (  ) external view returns ( uint16 );
    function renounceOwnership (  ) external;
    function set ( uint256 _pid, uint256 _allocPoint, uint16 _depositFeeBP, uint256 _harvestInterval, bool _withUpdate ) external;
    function setFeeAddress ( address _feeAddress ) external;
    function setReferralCommissionRate ( uint16 _referralCommissionRate ) external;
    function setCoinkReferral ( address _coinkReferral ) external;
    function startBlock (  ) external view returns ( uint256 );
    function totalAllocPoint (  ) external view returns ( uint256 );
    function totalLockedUpRewards (  ) external view returns ( uint256 );
    function transferOwnership ( address newOwner ) external;
    function updateEmissionRate ( uint256 _coinkPerBlock ) external;
    function updatePool ( uint256 _pid ) external;
    function userInfo ( uint256, address ) external view returns ( uint256 amount, uint256 rewardDebt, uint256 rewardLockedUp, uint256 nextHarvestUntil );
    function coink (  ) external view returns ( address );
    function coinkPerBlock (  ) external view returns ( uint256 );
    function coinkReferral (  ) external view returns ( address );
    function withdraw ( uint256 _pid, uint256 _amount ) external;
}
