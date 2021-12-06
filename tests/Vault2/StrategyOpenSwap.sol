// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IOpenSwapChef.sol";
import "../interfaces/IWETH.sol";

import "./BaseStrategyLP.sol";

contract StrategyOpenSwap is BaseStrategyLP {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint256 public pid;
    address public masterchefAddress;

    constructor(
        address _vaultChefAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address _woneAddress,
        address _masterchefAddress,
        address _uniRouterAddress,
        address _rewardAddress,
        address[] memory _earnedToWonePath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;
        pid = _pid;

        wantAddress = _wantAddress;
        earnedAddress = _earnedAddress;
        woneAddress = _woneAddress;

        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        masterchefAddress = _masterchefAddress;
        uniRouterAddress = _uniRouterAddress;
        rewardAddress = _rewardAddress;

        earnedToWonePath = _earnedToWonePath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        transferOwnership(vaultChefAddress);
        
        _resetAllowances();
    }

    function _vaultDeposit(uint256 _amount) internal override {
        IOpenSwapChef(masterchefAddress).deposit(pid, _amount);
    }
    
    function _vaultWithdraw(uint256 _amount) internal override {
        IOpenSwapChef(masterchefAddress).withdraw(pid, _amount);
    }

    function earn() external override nonReentrant whenNotPaused onlyGov {
        // Harvest farm tokens
        IOpenSwapChef(masterchefAddress).deposit(pid, 0);

        // Converts farm tokens into want tokens
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt, earnedAddress);
            earnedAmt = distributeOperatorFees(earnedAmt, earnedAddress);
            earnedAmt = distributeRewards(earnedAmt, earnedAddress);
    
            if (earnedAddress != token0Address) {
                // Swap half earned to token0
                _safeSwap(
                    earnedAmt.div(2),
                    earnedToToken0Path,
                    address(this)
                );
            }
    
            if (earnedAddress != token1Address) {
                // Swap half earned to token1
                _safeSwap(
                    earnedAmt.div(2),
                    earnedToToken1Path,
                    address(this)
                );
            }
        }

        
        if (earnedAmt > 0) {
            // Get want tokens, ie. add liquidity
            uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));
            uint256 token1Amt = IERC20(token1Address).balanceOf(address(this));
            if (token0Amt > 0 && token1Amt > 0) {
                IUniRouter02(uniRouterAddress).addLiquidity(
                    token0Address,
                    token1Address,
                    token0Amt,
                    token1Amt,
                    0,
                    0,
                    address(this),
                    now.add(600)
                );
            }
            lastEarnBlock = block.number;
            _farm();
        }
    }

    // To pay for earn function
    function distributeFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt.mul(controllerFee).div(feeMax);
            
            if (_earnedAddress == woneAddress) {
                IWETH(woneAddress).withdraw(fee);
                safeTransferETH(controllerFeeAddress, fee);
            } else {
                _safeSwapWone(fee, earnedToWonePath, controllerFeeAddress);
            }
            _earnedAmt = _earnedAmt.sub(fee);
        }
        return _earnedAmt;
    }

    function distributeOperatorFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (operatorFee > 0) {
            uint256 fee = _earnedAmt.mul(operatorFee).div(feeMax);

            if (_earnedAddress == woneAddress) {
                IWETH(woneAddress).withdraw(fee);
                safeTransferETH(withdrawFeeAddress, fee);
            } else {
                _safeSwapWone(
                    fee,
                    earnedToWonePath,
                    withdrawFeeAddress
                );
            }
            _earnedAmt = _earnedAmt.sub(fee);
        }
        return _earnedAmt;
    }

    function distributeRewards(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (rewardRate > 0) {
            uint256 fee = _earnedAmt.mul(rewardRate).div(feeMax);

            if (_earnedAddress == woneAddress) {
                IStrategyBurnVault(rewardAddress).depositReward(fee);
            } else {
                uint256 woneBefore = IERC20(woneAddress).balanceOf(address(this));
                _safeSwap(
                    fee,
                    earnedToWonePath,
                    address(this)
                );
                uint256 woneAfter = IERC20(woneAddress).balanceOf(address(this)).sub(woneBefore);
                IStrategyBurnVault(rewardAddress).depositReward(woneAfter);
            }
            _earnedAmt = _earnedAmt.sub(fee);
        }
        return _earnedAmt;
    }
    
    function vaultSharesTotal() public override view returns (uint256) {
        (uint256 balance,) = IOpenSwapChef(masterchefAddress).userInfo(pid, address(this));
        return balance;
    }
    
    function wantLockedTotal() public override view returns (uint256) {
        (uint256 balance,) = IOpenSwapChef(masterchefAddress).userInfo(pid, address(this));
        return IERC20(wantAddress).balanceOf(address(this)).add(balance);
    }

    function _resetAllowances() internal override {
        // Approve the burn vaults for deposits
        IERC20(woneAddress).safeApprove(rewardAddress, uint256(0));
        IERC20(woneAddress).safeIncreaseAllowance(
            rewardAddress,
            uint256(-1)
        );

        IERC20(wantAddress).safeApprove(masterchefAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            masterchefAddress,
            uint256(-1)
        );

        IERC20(earnedAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(woneAddress).safeApprove(uniRouterAddress, uint256(0));
        IERC20(woneAddress).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token0Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token0Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

        IERC20(token1Address).safeApprove(uniRouterAddress, uint256(0));
        IERC20(token1Address).safeIncreaseAllowance(
            uniRouterAddress,
            uint256(-1)
        );

    }

    function _emergencyVaultWithdraw() internal override {
        IOpenSwapChef(masterchefAddress).withdraw(pid, vaultSharesTotal());
    }

    function emergencyPanic() external onlyGov {
        _pause();
        IOpenSwapChef(masterchefAddress).emergencyWithdraw(pid);
    }

    receive() external payable {}
}