// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IStake {
    function deposit ( uint256 amount ) external;
    function redeem ( uint256 amount ) external;
    function claimRewards (  ) external;
    function supplyAmount ( address ) external view returns ( uint256 );
}