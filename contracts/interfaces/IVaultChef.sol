// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

interface IVaultChef {
    function operators ( address ) external view returns ( bool );
    function owner (  ) external view returns ( address );
    function poolInfo ( uint256 ) external view returns ( address want, address strat );
    function renounceOwnership (  ) external;
    function transferOwnership ( address newOwner ) external;
    function updateOperator ( address _operator, bool _status ) external;
    function userInfo ( uint256, address ) external view returns ( uint256 shares );
    function poolLength (  ) external view returns ( uint256 );
    function addPool ( address _strat ) external;
    function stakedWantTokens ( uint256 _pid, address _user ) external view returns ( uint256 );
    function deposit ( uint256 _pid, uint256 _wantAmt, address _to ) external;
    function deposit ( uint256 _pid, uint256 _wantAmt ) external;
    function withdraw ( uint256 _pid, uint256 _wantAmt, address _to ) external;
    function withdraw ( uint256 _pid, uint256 _wantAmt ) external;
    function withdrawAll ( uint256 _pid ) external;
    function resetAllowances (  ) external;
    function resetSingleAllowance ( uint256 _pid ) external;
}