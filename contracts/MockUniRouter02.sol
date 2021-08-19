// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "github.com/OpenZeppelin/openzeppelin-contracts/blob/release-v3.1.0/contracts/token/ERC20/SafeERC20.sol";

contract MockUniRouter02 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public lpToken;

    constructor(
        address _lpToken
    ) public {
        lpToken = _lpToken;
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public view returns (uint[] memory amounts)
    {
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        return amounts;
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        // Just trades tokens 1for1
        IERC20(path[0]).safeTransferFrom(
            address(msg.sender),
            address(this),
            amountIn
        );
        IERC20(path[path.length.sub(1)]).safeTransfer(to, amountIn);
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        return amounts;
    }

    function swapExactTokensForETH(
        uint amountIn,
        address[] calldata path,
        address to,
        uint deadline)
        external returns (uint[] memory amounts)
    {
        // Just trades tokens 1for1 for ETH
        IERC20(path[0]).safeTransferFrom(
            address(msg.sender),
            address(this),
            amountIn
        );
        safeTransferETH(to, amountIn);

        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        return amounts;
    }

    function addLiquidity(
        address token0,
        address token1,
        uint amount0,
        uint amount1,
        uint minAmount0,
        uint minAmount1,
        address to,
        uint deadline)
        external returns (uint[] memory amounts)
    {
        // Take in amount but leave some dust from the 2nd one
        IERC20(token0).safeTransferFrom(
            address(msg.sender),
            address(this),
            amount0
        );
        IERC20(token1).safeTransferFrom(
            address(msg.sender),
            address(this),
            amount1.mul(98).div(100)
        );

        // Send LP Token
        IERC20(token1).safeTransfer(
            address(msg.sender),
            amount0
        );

        amounts = new uint[](2);
        amounts[0] = amount0;
        amounts[1] = amount1.mul(98).div(100);
        return amounts;
    }

    function safeTransferETH(address to, uint256 value) internal {
        (bool success, ) = to.call{value: value}(new bytes(0));
        require(success, 'TransferHelper::safeTransferETH: ETH transfer failed');
    }

}