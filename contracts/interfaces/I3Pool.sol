// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface I3Pool {
    function add_liquidity ( uint256[] memory amounts, uint256 min_mint_amount ) external;
}