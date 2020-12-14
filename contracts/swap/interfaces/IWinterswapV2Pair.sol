// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "./IWinterswapV2HRC20.sol";

interface IWinterswapV2Pair is IWinterswapV2HRC20{

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event SwapFree(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event TransferTxFee(address indexed token, address to, uint256 amount);
    event Sync(uint112 reserve0, uint112 reserve1);
    event FeeToGovenance(address indexed token, address indexed to, uint256 amount);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function swap_free(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function transfer_tx_fee(uint256 amount, address token, address to) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address, address) external;
}
