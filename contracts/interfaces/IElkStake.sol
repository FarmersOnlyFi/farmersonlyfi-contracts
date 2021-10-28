// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IElkStake {
    function balanceOf ( address account ) external view returns ( uint256 );
    function earned ( address account ) external view returns ( uint256 );
    function exit (  ) external;
    function getCoverage (  ) external;
    function getReward (  ) external;
    function rewards ( address ) external view returns ( uint256 );
    function stake ( uint256 amount ) external;
    function withdraw ( uint256 amount ) external;
}