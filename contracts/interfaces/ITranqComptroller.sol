// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITranqComptroller {
    function markets ( address ) external view returns ( bool isListed, uint256 collateralFactorMantissa, bool isTranqed );
    function enterMarkets ( address[] calldata tqTokens ) external returns ( uint256[] memory );
    function exitMarket ( address tqTokenAddress ) external returns ( uint256 );
    function claimReward ( uint8 rewardType, address holder ) external;
}