// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/Pausable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/utils/ReentrancyGuard.sol";

import "../interfaces/ITranqToken.sol";
import "../interfaces/ITranqComptroller.sol";
import "../interfaces/IStrategyBurnVault.sol";
import "../interfaces/IUniPair.sol";
import "../interfaces/IUniRouter02.sol";
import "../interfaces/IWETH.sol";

contract StrategyTranquil is Ownable, ReentrancyGuard, Pausable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant comptrollerAddress = 0x6a82A17B48EF6be278BBC56138F35d04594587E3;
    address public controllerFeeAddress = 0xB989B490F9899a5AD56a4255A3C84457040B59dc; //0x54EfdaE67807cf4394020e48c7262bdbbdEbd9F2;
    address public withdrawFeeAddress = 0xB989B490F9899a5AD56a4255A3C84457040B59dc;
    address public wantAddress;
    address public tqTokenAddress;
    address public earnedAddress;

    address public uniRouterAddress;
    address public woneAddress;
    address public rewardAddress;
    address public vaultChefAddress;
    address public govAddress;

    uint256 public lastEarnBlock = block.number;
    uint256 public sharesTotal = 0;

    uint256 public controllerFee = 40;
    uint256 public operatorFee = 60;
    uint256 public rewardRate = 300;
    uint256 public constant feeMaxTotal = 1000;
    uint256 public constant feeMax = 10000; // 100 = 1%

    uint256 public withdrawFeeFactor = 9980; // 0.1% withdraw fee
    uint256 public constant withdrawFeeFactorMax = 10000;
    uint256 public constant withdrawFeeFactorLL = 9900; // 1% max

    uint256 public slippageFactor = 950; // 5% default slippage tolerance
    uint256 public constant slippageFactorUL = 995;

    /**
     * @dev Variables that can be changed to config profitability and risk:
     * {borrowRate}          - At What % of our collateral do we borrow per leverage level.
     * {borrowDepth}         - How many levels of leverage do we take.
     * {BORROW_RATE_MAX}     - A limit on how much we can push borrow risk.
     * {BORROW_DEPTH_MAX}    - A limit on how many steps we can leverage.
     */
    uint256 public borrowRate;
    uint256 public borrowDepth = 6;
    uint256 public minLeverage;
    uint256 public BORROW_RATE_MAX;
    uint256 public BORROW_RATE_MAX_HARD;
    uint256 public BORROW_DEPTH_MAX = 8;
    uint256 public constant BORROW_RATE_DIVISOR = 10000;

    address[] public earnedToWonePath;
    address[] public earnedToWantPath;

    constructor(
        address _vaultChefAddress,
        uint256 _minLeverage,
        address _tqTokenAddress,
        address _woneAddress,
        address _wantAddress,
        address _earnedAddress,
        address _uniRouterAddress,
        address _rewardAddress,
        address[] memory _earnedToWonePath,
        address[] memory _earnedToWantPath
    ) public {
        govAddress = msg.sender;
        vaultChefAddress = _vaultChefAddress;

        minLeverage = _minLeverage;

        tqTokenAddress = _tqTokenAddress;
        woneAddress = _woneAddress;
        wantAddress = _wantAddress;
        earnedAddress = _earnedAddress;
        uniRouterAddress = _uniRouterAddress;
        rewardAddress = _rewardAddress;

        earnedToWonePath = _earnedToWonePath;
        earnedToWantPath = _earnedToWantPath;

        (, uint256 collateral, ) = ITranqComptroller(comptrollerAddress).markets(tqTokenAddress);

        // At minimum, borrow rate always 10% lower than liquidation threshold
        BORROW_RATE_MAX = collateral.mul(90).div(100).mul(BORROW_RATE_DIVISOR).div(1e18); // 10%
        BORROW_RATE_MAX_HARD = collateral.mul(99).div(100).mul(BORROW_RATE_DIVISOR).div(1e18); // 1%
        borrowRate = BORROW_RATE_MAX;
        // Enable borrowing
        address[] memory markets = new address[](1);
        markets[0] = tqTokenAddress;
        ITranqComptroller(comptrollerAddress).enterMarkets(markets);

        transferOwnership(vaultChefAddress);

        _resetAllowances();
    }

    event SetSettings(
        uint256 _controllerFee,
        uint256 _operatorFee,
        uint256 _rewardRate,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress,
        address _rewardAddress,
        address _withdrawFeeAddress,
        address _controllerFeeAddress
    );

    modifier onlyGov() {
        require(msg.sender == govAddress, "!gov");
        _;
    }

    function deposit(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant whenNotPaused returns (uint256) {
        // Call must happen before transfer
        uint256 wantLockedBefore = wantLockedTotal();

        IERC20(wantAddress).safeTransferFrom(
            address(msg.sender),
            address(this),
            _wantAmt
        );

        // Proper deposit amount for tokens with fees, or vaults with deposit fees
        uint256 sharesAdded = _farm(_wantAmt);
        if (sharesTotal > 0) {
            sharesAdded = sharesAdded.mul(sharesTotal).div(wantLockedBefore);
        }
        sharesTotal = sharesTotal.add(sharesAdded);

        return sharesAdded;
    }

    function _farm(uint256 _wantAmt) internal returns (uint256) {
        uint256 wantAmt = wantLockedInHere();
        if (wantAmt == 0) return 0;


        uint256 sharesBefore = wantLockedTotal().sub(_wantAmt);
        _leverage(wantAmt);

        return wantLockedTotal().sub(sharesBefore);
    }

    function withdraw(address _userAddress, uint256 _wantAmt) external onlyOwner nonReentrant returns (uint256) {
        require(_wantAmt > 0, "_wantAmt is 0");

        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));

        if (_wantAmt > wantAmt) {
            // Fully deleverage, cheap on Harmony
            _deleverage();
            wantAmt = IERC20(wantAddress).balanceOf(address(this));
        }

        if (_wantAmt > wantAmt) {
            _wantAmt = wantAmt;
        }

        if (_wantAmt > wantLockedTotal()) {
            _wantAmt = wantLockedTotal();
        }

        uint256 sharesRemoved = _wantAmt.mul(sharesTotal).div(wantLockedTotal());
        if (sharesRemoved > sharesTotal) {
            sharesRemoved = sharesTotal;
        }
        sharesTotal = sharesTotal.sub(sharesRemoved);

        // Withdraw fee
        uint256 withdrawFee = _wantAmt
        .mul(withdrawFeeFactorMax.sub(withdrawFeeFactor))
        .div(withdrawFeeFactorMax);
        if (withdrawFee > 0) {
            IERC20(wantAddress).safeTransfer(withdrawFeeAddress, withdrawFee);
        }

        _wantAmt = _wantAmt.sub(withdrawFee);

        IERC20(wantAddress).safeTransfer(vaultChefAddress, _wantAmt);

        if (!paused()) {
            // Put it all back in
            _leverage(wantLockedInHere());
        }

        return sharesRemoved;
    }

    function _supply(uint256 _amount) internal {
        ITranqToken(tqTokenAddress).mint(_amount);
    }

    function _removeSupply(uint256 _amount) internal {
        // Need to convert the amount into tq token amounts
        uint256 tqAmount;
        if (_amount == uint256(-1)) {
            tqAmount = _amount;
        } else {
            tqAmount = _amount.mul(1e18).div(ITranqToken(tqTokenAddress).exchangeRateStored());
        }
        if (tqAmount > IERC20(tqTokenAddress).balanceOf(address(this))) {
            tqAmount = IERC20(tqTokenAddress).balanceOf(address(this));
        }
        ITranqToken(tqTokenAddress).redeem(tqAmount);
    }

    function _borrow(uint256 _amount) internal {
        ITranqToken(tqTokenAddress).borrow(_amount);
    }

    function _repayBorrow(uint256 _amount) internal {
        if (_amount > debtTotal()) {
            _amount = debtTotal();
        }
        if (_amount > 0) {
            ITranqToken(tqTokenAddress).repayBorrow(_amount);
        }
    }

    /**
     * @dev Deposits token, withdraws a percentage, and deposits again
     * We stop at _borrow because we need some tokens to deleverage
     */
    function _leverage(uint256 _amount) internal {
        if (borrowDepth == 0) {
            _supply(_amount);
        } else if (_amount > minLeverage) {
            for (uint256 i = 0; i < borrowDepth; i++) {
                _supply(_amount);
                _amount = _amount.mul(borrowRate).div(BORROW_RATE_DIVISOR);
                _borrow(_amount);
            }
        }
    }

    /**
     * @dev Manually wind back one step in case contract gets stuck
     */
    function deleverageOnce() external onlyGov {
        _deleverageOnce();
    }

    function _deleverageOnce() internal {
        if (tqTokenTotal() <= supplyBalTargeted()) {
            _removeSupply(tqTokenTotal().sub(supplyBalMin()));
        } else {
            _removeSupply(tqTokenTotal().sub(supplyBalTargeted()));
        }

        _repayBorrow(wantLockedInHere());
    }

    /**
     * @dev In Polygon, we can fully deleverage due to absurdly cheap fees
     */
    function _deleverage() internal {
        uint256 wantBal = wantLockedInHere();

        if (borrowDepth > 0) {
            while (wantBal < debtTotal()) {
                _repayBorrow(wantBal);
                _removeSupply(tqTokenTotal().sub(supplyBalMin()));
                wantBal = wantLockedInHere();
            }

            _repayBorrow(wantBal);
        }
        _removeSupply(uint256(-1));
    }

    function earn() external nonReentrant whenNotPaused onlyGov {
        uint256 preEarn = IERC20(earnedAddress).balanceOf(address(this));

        // Harvest farm tokens
        ITranqComptroller(comptrollerAddress).claimReward(0, address(this));

        // Because we keep some tokens in this contract, we have to do this if earned is the same as want
        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this)).sub(preEarn);

        if (earnedAmt > 0) {
            earnedAmt = distributeFees(earnedAmt, earnedAddress);
            earnedAmt = distributeOperatorFees(earnedAmt, earnedAddress);
            earnedAmt = distributeRewards(earnedAmt, earnedAddress);

            if (earnedAddress != wantAddress) {
                _safeSwap(
                    earnedAmt,
                    earnedToWantPath,
                    address(this)
                );
            }

            lastEarnBlock = block.number;

            _leverage(wantLockedInHere());
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

    // Emergency!!
    function pause() external onlyGov {
        _pause();
    }

    // False alarm
    function unpause() external onlyGov {
        _unpause();
        _resetAllowances();
    }

    function debtTotal() public view returns (uint256) {
        return ITranqToken(tqTokenAddress).borrowBalanceStored(address(this));
    }

    function supplyBalTargeted() public view returns (uint256) {
        return debtTotal().mul(BORROW_RATE_DIVISOR).div(borrowRate);
    }

    function supplyBalMin() public view returns (uint256) {
        return debtTotal().mul(BORROW_RATE_DIVISOR).div(BORROW_RATE_MAX_HARD);
    }

    function tqTokenTotal() public view returns (uint256) {
        uint256 tqBalance = IERC20(tqTokenAddress).balanceOf(address(this));
        return tqBalance.mul(ITranqToken(tqTokenAddress).exchangeRateStored()).div(1e18);
    }

    function wantLockedInHere() public view returns (uint256) {
        return IERC20(wantAddress).balanceOf(address(this));
    }

    function wantLockedTotal() public view returns (uint256) {
        return wantLockedInHere()
        .add(tqTokenTotal())
        .sub(debtTotal());
    }

    function _resetAllowances() internal {
        IERC20(wantAddress).safeApprove(tqTokenAddress, uint256(0));
        IERC20(wantAddress).safeIncreaseAllowance(
            tqTokenAddress,
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

        IERC20(woneAddress).safeApprove(rewardAddress, uint256(0));
        IERC20(woneAddress).safeIncreaseAllowance(
            rewardAddress,
            uint256(-1)
        );
    }

    function resetAllowances() external onlyGov {
        _resetAllowances();
    }

    function panic() external onlyGov {
        _pause();
        _deleverage();
    }

    function unpanic() external onlyGov {
        _unpause();
        _leverage(wantLockedInHere());
    }


    function rebalance(uint256 _borrowRate, uint256 _borrowDepth) external onlyGov {
        require(_borrowRate <= BORROW_RATE_MAX, "!rate");
        require(_borrowRate != 0, "borrowRate is used as a divisor");
        require(_borrowDepth <= BORROW_DEPTH_MAX, "!depth");

        _deleverage();
        borrowRate = _borrowRate;
        borrowDepth = _borrowDepth;
        _leverage(wantLockedInHere());
    }

    function setSettings(
        uint256 _controllerFee,
        uint256 _operatorFee,
        uint256 _rewardRate,
        uint256 _withdrawFeeFactor,
        uint256 _slippageFactor,
        address _uniRouterAddress,
        address _rewardAddress,
        address _withdrawFeeAddress,
        address _controllerFeeAddress
    ) external onlyGov {
        require(_controllerFee.add(_operatorFee).add(_rewardRate) <= feeMaxTotal, "Max fee of 10%");
        require(_withdrawFeeFactor >= withdrawFeeFactorLL, "_withdrawFeeFactor too low");
        require(_withdrawFeeFactor <= withdrawFeeFactorMax, "_withdrawFeeFactor too high");
        require(_slippageFactor <= slippageFactorUL, "_slippageFactor too high");
        controllerFee = _controllerFee;
        operatorFee = _operatorFee;
        rewardRate = _rewardRate;
        withdrawFeeFactor = _withdrawFeeFactor;
        slippageFactor = _slippageFactor;
        uniRouterAddress = _uniRouterAddress;

        rewardAddress = _rewardAddress;
        withdrawFeeAddress = _withdrawFeeAddress;
        controllerFeeAddress = _controllerFeeAddress;

        emit SetSettings(
            _controllerFee,
            _operatorFee,
            _rewardRate,
            _withdrawFeeFactor,
            _slippageFactor,
            _uniRouterAddress,
            _rewardAddress,
            _withdrawFeeAddress,
            _controllerFeeAddress
        );
    }

    function setGov(address _govAddress) external onlyGov {
        govAddress = _govAddress;
    }

    function _safeSwap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IUniRouter02(uniRouterAddress).swapExactTokensForTokens(
            _amountIn,
            amountOut.mul(slippageFactor).div(1000),
            _path,
            _to,
            now.add(600)
        );
    }

    function _safeSwapWone(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) internal {
        uint256[] memory amounts = IUniRouter02(uniRouterAddress).getAmountsOut(_amountIn, _path);
        uint256 amountOut = amounts[amounts.length.sub(1)];

        IUniRouter02(uniRouterAddress).swapExactTokensForETH(
            _amountIn,
            amountOut.mul(slippageFactor).div(1000),
            _path,
            _to,
            now.add(600)
        );
    }
    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }

    // tg @macatkevin
    receive() external payable {}
}