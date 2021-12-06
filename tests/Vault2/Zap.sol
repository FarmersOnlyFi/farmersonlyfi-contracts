// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/access/Ownable.sol";
import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/IUniRouter02.sol";
import "../interfaces/IUniPair.sol";
import "../interfaces/IVaultChef.sol";
import "../interfaces/IWETH.sol";

contract Zap is Ownable {
    /*
    zapIn              | 0.25% fee. Goes from ETH -> LP tokens and return dust.
    zapInToken         | 0.25% fee. Goes from ERC20 token -> LP and returns dust.
    zapInAndStake      | No fee.    Goes from ETH -> LP -> Vault and returns dust.
    zapInTokenAndStake | No fee.    Goes from ERC20 token -> LP -> Vault and returns dust.
    zapOut             | No fee.    Breaks LP token and trades it back for ETH.
    zapOutToken        | No fee.    Breaks LP token and trades it back for desired token.
    swap               | No fee.    token for token. Allows us to have a $FOX swap on our site (sitting on top of DFK or Sushi)
    */
    using SafeMath for uint;
    using SafeERC20 for IERC20;

    /* ========== STATE VARIABLES ========== */

    address public WNATIVE;
    address public vaultChefAddress;
    address private FEE_TO_ADDR;
    uint16 FEE_RATE;
    uint16 MIN_AMT;
    mapping(address => mapping(address => address)) private tokenBridgeForRouter;

    event FeeChange(address fee_to, uint16 rate, uint16 min);

    mapping (address => bool) public useNativeRouter;

    constructor(address _WNATIVE, address _vaultChefAddress, address feeAddress) public Ownable() {
        WNATIVE = _WNATIVE;
        vaultChefAddress = _vaultChefAddress;
        FEE_TO_ADDR = feeAddress;
        FEE_RATE = 400;  // Math is: fee = amount/FEE_RATE, so 400 = 0.25%
        MIN_AMT = 1000;
    }

    /* ========== External Functions ========== */

    receive() external payable {}

    function zapIn(
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1
    ) external payable {
        // from Native to an LP token through the specified router
        require(uint(msg.value) > MIN_AMT, "INPUT_TOO_LOW");
        uint fee = uint(msg.value).div(FEE_RATE);

        IWETH(WNATIVE).deposit{value: uint(msg.value).sub(fee)}();
        _approveTokenIfNeeded(WNATIVE, routerAddr);
        _swapTokenToLP(WNATIVE, uint(msg.value).sub(fee), _to,  _recipient, routerAddr, path0, path1);
        safeTransferETH(FEE_TO_ADDR, fee);
    }

    function zapInToken(
        address _from,
        uint amount,
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1
    ) external {
        // From an ERC20 to an LP token, through specified router
        require(amount > MIN_AMT, "INPUT_TOO_LOW");
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        // we'll need this approval to swap
        _approveTokenIfNeeded(_from, routerAddr);

        // Take fee first because _swapTokenToLP will return dust
        uint fee = uint(amount).div(FEE_RATE);
        IERC20(_from).safeTransfer(FEE_TO_ADDR, IERC20(_from).balanceOf(address(this)));
        _swapTokenToLP(_from, amount.sub(fee), _to, _recipient, routerAddr, path0, path1);
    }

    function zapInAndStake(
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1,
        uint vaultPid
    ) external payable {
        // Also stakes in vault, no fees
        require(uint(msg.value) > MIN_AMT, "INPUT_TOO_LOW");
        (address vaultWant,) = IVaultChef(vaultChefAddress).poolInfo(vaultPid);
        require(vaultWant  == _to, "Wrong wantAddress for vault pid");

        IWETH(WNATIVE).deposit{value: uint(msg.value)}();
        _approveTokenIfNeeded(WNATIVE, routerAddr);
        uint lps = _swapTokenToLP(WNATIVE, uint(msg.value), _to, address(this), routerAddr, path0, path1);

        _approveTokenIfNeeded(_to, vaultChefAddress);
        IVaultChef(vaultChefAddress).deposit(vaultPid, lps, _recipient);
    }

    function zapInTokenAndStake(
        address _from,
        uint amount,
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1,
        uint vaultPid
    ) external {
        // Also stakes in vault, no fees
        require(amount > MIN_AMT, "INPUT_TOO_LOW");
        (address vaultWant,) = IVaultChef(vaultChefAddress).poolInfo(vaultPid);
        require(vaultWant  == _to, "Wrong wantAddress for vault pid");
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from, routerAddr);
        uint lps = _swapTokenToLP(_from, amount, _to, address(this), routerAddr, path0, path1);
        _approveTokenIfNeeded(_to, vaultChefAddress);
        IVaultChef(vaultChefAddress).deposit(vaultPid, lps, _recipient);
    }

    function zapOut(
        address _from,
        uint amount,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1) external {
        // from an LP token to Native through specified router
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from, routerAddr);

        // get pairs for LP
        address token0 = IUniPair(_from).token0();
        address token1 = IUniPair(_from).token1();
        _approveTokenIfNeeded(token0, routerAddr);
        _approveTokenIfNeeded(token1, routerAddr);
        // convert both for Native with msg.sender as recipient
        uint amt0;
        uint amt1;
        (amt0, amt1) = IUniRouter02(routerAddr).removeLiquidity(token0, token1, amount, 0, 0, address(this), block.timestamp);
        _swapTokenForNative(token0, amt0, _recipient, routerAddr, path0);
        _swapTokenForNative(token1, amt1, _recipient, routerAddr, path1);
    }

    function zapOutToken(
        address _from,
        uint amount,
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path0,
        address[] memory path1
    ) external {
        // from an LP token to an ERC20 through specified router
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from, routerAddr);

        address token0 = IUniPair(_from).token0();
        address token1 = IUniPair(_from).token1();
        _approveTokenIfNeeded(token0, routerAddr);
        _approveTokenIfNeeded(token1, routerAddr);
        uint amt0;
        uint amt1;
        (amt0, amt1) = IUniRouter02(routerAddr).removeLiquidity(token0, token1, amount, 0, 0, address(this), block.timestamp);
        if (token0 != _to) {
            amt0 = _swap(token0, amt0, _to, address(this), routerAddr, path0);
        }
        if (token1 != _to) {
            amt1 = _swap(token1, amt1, _to, address(this), routerAddr, path1);
        }
        _returnAssets(_to);
    }

    function swapToken(
        address _from,
        uint amount,
        address _to,
        address routerAddr,
        address _recipient,
        address[] memory path
    ) external {
        IERC20(_from).safeTransferFrom(msg.sender, address(this), amount);
        _approveTokenIfNeeded(_from, routerAddr);
        _swap(_from, amount, _to, _recipient, routerAddr, path);
    }

    /* ========== Private Functions ========== */

    function _approveTokenIfNeeded(address token, address router) private {
        if (IERC20(token).allowance(address(this), router) == 0) {
            IERC20(token).safeApprove(router, type(uint).max);
        }
    }

    function _returnAssets(address token) private {
        uint256 balance;
        balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            if (token == WNATIVE) {
                IWETH(WNATIVE).withdraw(balance);
                safeTransferETH(msg.sender, balance);
            } else {
                IERC20(token).safeTransfer(msg.sender, balance);
            }
        }
    }

    function _swapTokenToLP(
        address _from,
        uint amount,
        address _to,
        address recipient,
        address routerAddr,
        address[] memory path0,
        address[] memory path1
    ) private returns (uint) {
        // get pairs for desired lp
        // we're going to sell 1/2 of _from for each lp token
        uint amt0 = amount.div(2);
        uint amt1 = amount.div(2);
        if (_from != IUniPair(_to).token0()){
            // execute swap
            amt0 = _swap(_from, amount.div(2), IUniPair(_to).token0(), address(this), routerAddr, path0);
        }
        if (_from != IUniPair(_to).token1()) {
            // execute swap
            amt1 = _swap(_from, amount.div(2), IUniPair(_to).token1(), address(this), routerAddr, path1);
        }
        _approveTokenIfNeeded(IUniPair(_to).token0(), routerAddr);
        _approveTokenIfNeeded(IUniPair(_to).token1(), routerAddr);
        ( , , uint liquidity) = IUniRouter02(routerAddr).addLiquidity(
            IUniPair(_to).token0(),
            IUniPair(_to).token1(),
            amt0, amt1, 0, 0,
            recipient, block.timestamp);
        // Return dust after liquidity is added
        _returnAssets(IUniPair(_to).token0());
        _returnAssets(IUniPair(_to).token1());
        return liquidity;
    }

    function _swap(
        address _from,
        uint amount,
        address _to,
        address recipient,
        address routerAddr,
        address[] memory path
    ) private returns (uint) {
        if (_from == _to) {
            // Let the swaps handle this logic as well as the path validation
            return amount;
        }
        require(path[0] == _from, 'Bad path');
        require(path[path.length - 1] == _to, 'Bad path');

        IUniRouter02 router = IUniRouter02(routerAddr);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amount, 0, path, recipient, block.timestamp);
        return IERC20(path[path.length - 1]).balanceOf(address(this));
    }

    function _swapTokenForNative(address token, uint amount, address recipient, address routerAddr, address[] memory path) private returns (uint) {
        if (token == WNATIVE) {
            // Just withdraw and send
            IWETH(WNATIVE).withdraw(amount);
            safeTransferETH(recipient, amount);
            return amount;
        }
        IUniRouter02 router = IUniRouter02(routerAddr);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(amount, 0, path, recipient, block.timestamp);
        return IERC20(path[path.length - 1]).balanceOf(address(this));
    }

    function getWantForVault(uint pid) public returns (address) {
        (address wantAddress,) = IVaultChef(vaultChefAddress).poolInfo(pid);
        return wantAddress;
    }

        /* ========== RESTRICTED FUNCTIONS ========== */

    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }

    function setFee(address addr, uint16 rate, uint16 min) external onlyOwner {
        require(rate >= 25, "FEE TOO HIGH; MAX FEE = 4%");
        FEE_TO_ADDR = addr;
        FEE_RATE = rate;
        MIN_AMT = min;
        emit FeeChange(addr, rate, min);
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }
}
