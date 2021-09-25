// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IViperBridgePool {
    function PRECISION_FACTOR (  ) external view returns ( uint256 );
    function SMART_CHEF_FACTORY (  ) external view returns ( address );
    function accTokenPerShare (  ) external view returns ( uint256 );
    function deposit ( uint256 _amount ) external;
    function emergencyRewardWithdraw ( uint256 _amount ) external;
    function emergencyWithdraw (  ) external;
    function endBlock (  ) external view returns ( uint256 );
    function hasUserLimit (  ) external view returns ( bool );
    function initialize ( address _stakedToken, address _rewardToken, uint256 _rewardPerBlock, uint256 _startBlock, uint256 _endBlock, uint256 _poolLimitPerUser, address _admin ) external;
    function isInitialized (  ) external view returns ( bool );
    function lastRewardBlock (  ) external view returns ( uint256 );
    function owner (  ) external view returns ( address );
    function pendingReward ( address _user ) external view returns ( uint256 );
    function poolLimitPerUser (  ) external view returns ( uint256 );
    function recoverWrongTokens ( address _tokenAddress, uint256 _tokenAmount ) external;
    function renounceOwnership (  ) external;
    function rewardPerBlock (  ) external view returns ( uint256 );
    function rewardToken (  ) external view returns ( address );
    function stakedToken (  ) external view returns ( address );
    function startBlock (  ) external view returns ( uint256 );
    function stopReward (  ) external;
    function transferOwnership ( address newOwner ) external;
    function updatePoolLimitPerUser ( bool _hasUserLimit, uint256 _poolLimitPerUser ) external;
    function updateRewardPerBlock ( uint256 _rewardPerBlock ) external;
    function updateStartAndEndBlocks ( uint256 _startBlock, uint256 _endBlock ) external;
    function userInfo ( address ) external view returns ( uint256 amount, uint256 rewardDebt );
    function withdraw ( uint256 _amount ) external;
}