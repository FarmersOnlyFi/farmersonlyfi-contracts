// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface I3PoolStake {
    function claim_rewards (  ) external;
    function deposit ( uint256 _value ) external;
    function withdraw ( uint256 _value ) external;
    function withdraw ( uint256 _value, bool _claim_rewards ) external;
    function approve ( address _spender, uint256 _value ) external returns ( bool );
    function lp_token (  ) external view returns ( address );
    function balanceOf ( address arg0 ) external view returns ( uint256 );
    function totalSupply (  ) external view returns ( uint256 );
    function reward_tokens ( uint256 arg0 ) external view returns ( address );
    function reward_balances ( address arg0 ) external view returns ( uint256 );
}

