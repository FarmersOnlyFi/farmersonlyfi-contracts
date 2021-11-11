// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface ITranqToken {
    function mint ( uint256 mintAmount ) external returns ( uint256 );
    function redeem ( uint256 redeemTokens ) external returns ( uint256 );
    function borrow ( uint256 borrowAmount ) external returns ( uint256 );
    function repayBorrow ( uint256 repayAmount ) external returns ( uint256 );

    function balanceOf ( address owner ) external view returns ( uint256 );
    function balanceOfUnderlying ( address owner ) external returns ( uint256 );
    function borrowBalanceStored ( address account ) external view returns ( uint256 );
    function exchangeRateStored (  ) external view returns ( uint256 );
}