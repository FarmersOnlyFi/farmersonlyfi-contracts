// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/ISushiStake.sol";
import "../interfaces/IWETH.sol";
import "./BaseStrategyLP.sol";

contract StrategySushiBurn is BaseStrategyLP {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public foxAddress;
    address public masterchefAddress;
    uint256 public pid;

    address[] public woneToToken0Path;
    address[] public woneToToken1Path;
    address[] public woneToFoxPath;
    address[] public earnedToFoxPath;

    constructor(
        address _vaultChefAddress,
        address _uniRouterAddress,
        uint256 _pid,
        address _wantAddress,
        address _earnedAddress,
        address _masterchefAddress,
        address _woneAddress,
        address[] memory _earnedToWonePath,
        address[] memory _earnedToFoxPath,
        address[] memory _woneToFoxPath,
        address[] memory _earnedToToken0Path,
        address[] memory _earnedToToken1Path,
        address[] memory _woneToToken0Path,
        address[] memory _woneToToken1Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _token1ToEarnedPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        wantAddress = _wantAddress;
        token0Address = IUniPair(wantAddress).token0();
        token1Address = IUniPair(wantAddress).token1();

        uniRouterAddress = _uniRouterAddress;
        pid = _pid;
        earnedAddress = _earnedAddress;
        masterchefAddress = _masterchefAddress;
        woneAddress = _woneAddress;

        earnedToWonePath = _earnedToWonePath;
        earnedToFoxPath = _earnedToFoxPath;
        woneToFoxPath = _woneToFoxPath;
        earnedToToken0Path = _earnedToToken0Path;
        earnedToToken1Path = _earnedToToken1Path;
        woneToToken0Path = _woneToToken0Path;
        woneToToken1Path = _woneToToken1Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        token1ToEarnedPath = _token1ToEarnedPath;

        transferOwnership(vaultChefAddress);
        
        _resetAllowances();
    }

    function depositReward(uint256 _depositAmt) external returns (bool) {
        IWETH(woneAddress).transferFrom(msg.sender, address(this), _depositAmt);
        uint256 woneAmt = IERC20(woneAddress).balanceOf(address(this));

        if (woneAmt > 0) {
            woneAmt = distributeFees(woneAmt, woneAddress);
            woneAmt = distributeOperatorFees(woneAmt, woneAddress);

            if (woneAddress != token0Address) {
                // Swap half earned to token0
                _safeSwap(
                    woneAmt.div(2),
                    woneToToken0Path,
                    address(this)
                );
            }

            if (woneAddress != token1Address) {
                // Swap half earned to token1
                _safeSwap(
                    woneAmt.div(2),
                    woneToToken1Path,
                    address(this)
                );
            }
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
        }
        _farm();
        return true;
    }

    function _vaultDeposit(uint256 _amount) internal override {
        ISushiStake(masterchefAddress).deposit(pid, _amount, address(this));
    }
    
    function _vaultWithdraw(uint256 _amount) internal override {
        ISushiStake(masterchefAddress).withdraw(pid, _amount, address(this));
    }
    
    function vaultSharesTotal() public override view returns (uint256) {
        (uint256 amount,) = ISushiStake(masterchefAddress).userInfo(pid, address(this));
        return amount;
    }
    
    function wantLockedTotal() public override view returns (uint256) {
        (uint256 balance,) = ISushiStake(masterchefAddress).userInfo(pid, address(this));
        return IERC20(wantAddress).balanceOf(address(this)).add(balance);
    }

    function earn() external override nonReentrant whenNotPaused onlyGov {
        // Harvest farm tokens
        ISushiStake(masterchefAddress).harvest(pid, address(this));

        // Buys back FOX
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));
        uint256 woneAmt = IERC20(woneAddress).balanceOf(address(this));

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt, earnedAddress);
            earnedAmt = distributeOperatorFees(earnedAmt, earnedAddress);
            earnedAmt = buyBack(earnedAmt, earnedAddress);
    
            lastEarnBlock = block.number;
        }
        if (woneAmt > 0) {
            woneAmt = distributeFees(woneAmt, woneAddress);
            woneAmt = distributeOperatorFees(woneAmt, woneAddress);
            woneAmt = buyBack(woneAmt, woneAddress);

            lastEarnBlock = block.number;
        }
    }

    // To pay for earn function
    function distributeFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (controllerFee > 0) {
            uint256 fee = _earnedAmt.mul(controllerFee).div(feeMax);
            if (fee > 0) {
                if (_earnedAddress == woneAddress) {
                    IWETH(woneAddress).withdraw(fee);
                    safeTransferETH(controllerFeeAddress, fee);
                } else {
                    _safeSwapWone(fee, earnedToWonePath, controllerFeeAddress);
                }
                _earnedAmt = _earnedAmt.sub(fee);
            }
        }
        return _earnedAmt;
    }

    function distributeOperatorFees(uint256 _earnedAmt, address _earnedAddress) internal returns (uint256) {
        if (operatorFee > 0) {
            uint256 fee = _earnedAmt.mul(operatorFee).div(feeMax);
            if (fee > 0) {
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
        }
        return _earnedAmt;
    }


    function buyBack(uint256 buyBackAmt, address _earnedAddress) internal returns (uint256) {
        // Burn 100% of rewards!!!
        if (buyBackAmt > 0) {
            _safeSwap(
                buyBackAmt,
                _earnedAddress == woneAddress ? woneToFoxPath : earnedToFoxPath,
                buyBackAddress
            );
        }

        return 0;
    }

    function _resetAllowances() internal override {
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
        ISushiStake(masterchefAddress).withdraw(pid, vaultSharesTotal(), address(this));
    }

    function emergencyPanic() external onlyGov {
        _pause();
        ISushiStake(masterchefAddress).emergencyWithdraw(pid, msg.sender);
    }

    receive() external payable {}
}