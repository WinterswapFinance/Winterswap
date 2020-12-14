// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import './interfaces/IWinterswapV2Pair.sol';
import './WinterswapV2HRC20.sol';
import './libraries/MathSwap.sol';
import './libraries/UQ112x112.sol';
import '../openzeppelin/token/HRC20/IHRC20.sol';
import './interfaces/IWinterswapV2Factory.sol';
import './interfaces/IWinterswapV2Callee.sol';
import '../wns/IWNS.sol';

contract WinterswapV2Pair is IWinterswapV2Pair, WinterswapV2HRC20 {
    using SafeMathSwap  for uint;
    using UQ112x112 for uint224;


    uint256 constant PERMILLE = 1000;
    uint256 constant SWAP_FEE_PERMILLE = 5;

    uint override public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));

    address override public factory;
    address override public token0;
    address override public token1;

    uint112 private reserve0;           // uses single storage slot, accessible via getReserves
    uint112 private reserve1;           // uses single storage slot, accessible via getReserves
    uint32  private blockTimestampLast; // uses single storage slot, accessible via getReserves

    uint override public price0CumulativeLast;
    uint override public price1CumulativeLast;
    uint override public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'WinterswapV2: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    address router;

    modifier onlyRouter() {
        require(msg.sender == router, 'WinterswapV2: ONLY_ROUTER');
        _;
    }

    function getReserves() override public view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast) {

        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'WinterswapV2: TRANSFER_FAILED');
    }

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1, address _router) override external {
        require(msg.sender == factory, 'WinterswapV2: FORBIDDEN'); // sufficient check
        token0 = _token0;
        token1 = _token1;
        router = _router;
    }

    // update reserves and, on the first call per block, price accumulators
    function _update(uint balance0, uint balance1, uint112 _reserve0, uint112 _reserve1) private {
        require(balance0 <= uint112(-1) && balance1 <= uint112(-1), 'WinterswapV2: OVERFLOW');
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        uint32 timeElapsed = blockTimestamp - blockTimestampLast; // overflow is desired
        if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
            // * never overflows, and + overflow is desired
            price0CumulativeLast += uint(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
            price1CumulativeLast += uint(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserve0, reserve1);
    }

    // if fee is on, mint liquidity equivalent to 1/3th of the growth in sqrt(k)
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool feeOn) {
        address feeTo = IWinterswapV2Factory(factory).feeTo();
        feeOn = feeTo != address(0);
        uint _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint rootK = MathSwap.sqrt(uint(_reserve0).mul(_reserve1));
                uint rootKLast = MathSwap.sqrt(_kLast);
                if (rootK > rootKLast) {
                    uint numerator = totalSupply.mul(rootK.sub(rootKLast));
                    uint denominator = rootK.mul(2).add(rootKLast);//change 5 to 2
                    uint liquidity = numerator / denominator;
                    if (liquidity > 0) _mint(feeTo, liquidity);
                }
            }
        } else if (_kLast != 0) {
            kLast = 0;
        }
    }

    // this low-level function should be called from a contract which performs important safety checks
    function mint(address to) override external lock onlyRouter returns (uint liquidity) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        uint balance0 = IHRC20(token0).balanceOf(address(this));
        uint balance1 = IHRC20(token1).balanceOf(address(this));
        uint amount0 = balance0.sub(_reserve0);
        uint amount1 = balance1.sub(_reserve1);
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = MathSwap.sqrt(amount0.mul(amount1)).sub(MINIMUM_LIQUIDITY);
           _mint(address(0), MINIMUM_LIQUIDITY); // permanently lock the first MINIMUM_LIQUIDITY tokens
        } else {
            liquidity = MathSwap.min(amount0.mul(_totalSupply) / _reserve0, amount1.mul(_totalSupply) / _reserve1);
        }
        require(liquidity > 0, 'WinterswapV2: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Mint(msg.sender, amount0, amount1);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function burn(address to) override external lock onlyRouter returns (uint amount0, uint amount1) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        address _token0 = token0;                                // gas savings
        address _token1 = token1;                                // gas savings
        uint balance0 = IHRC20(_token0).balanceOf(address(this));
        uint balance1 = IHRC20(_token1).balanceOf(address(this));
        uint liquidity = balanceOf[address(this)];

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint _totalSupply = totalSupply; // gas savings, must be defined here since totalSupply can update in _mintFee
        amount0 = liquidity.mul(balance0) / _totalSupply; // using balances ensures pro-rata distribution
        amount1 = liquidity.mul(balance1) / _totalSupply; // using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, 'WinterswapV2: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        _safeTransfer(_token0, to, amount0);
        _safeTransfer(_token1, to, amount1);
        balance0 = IHRC20(_token0).balanceOf(address(this));
        balance1 = IHRC20(_token1).balanceOf(address(this));

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) kLast = uint(reserve0).mul(reserve1); // reserve0 and reserve1 are up-to-date
        emit Burn(msg.sender, amount0, amount1, to);
    }

    // this low-level function should be called from a contract which performs important safety checks
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) override external lock onlyRouter{
        require(amount0Out > 0 || amount1Out > 0, 'WinterswapV2: INSUFFICIENT_OUTPUT_AMOUNT');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'WinterswapV2: INSUFFICIENT_LIQUIDITY');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'WinterswapV2: INVALID_TO');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IWinterswapV2Callee(to).winterswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IHRC20(_token0).balanceOf(address(this));
            balance1 = IHRC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'WinterswapV2: INSUFFICIENT_INPUT_AMOUNT');
        { // scope for reserve{0,1}Adjusted, avoids stack too deep errors
            uint balance0Adjusted = balance0.mul(PERMILLE).sub(amount0In.mul(SWAP_FEE_PERMILLE));
            uint balance1Adjusted = balance1.mul(PERMILLE).sub(amount1In.mul(SWAP_FEE_PERMILLE));
            require(balance0Adjusted.mul(balance1Adjusted) >= uint(_reserve0).mul(_reserve1).mul(PERMILLE**2), 'WinterswapV2: K');
        }

        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    function swap_free(uint amount0Out, uint amount1Out, address to, bytes calldata data) override external lock onlyRouter{
        require(amount0Out > 0 || amount1Out > 0, 'WinterswapV2: INSUFFICIENT_OUTPUT_AMOUNT_FREE');
        (uint112 _reserve0, uint112 _reserve1,) = getReserves(); // gas savings
        require(amount0Out < _reserve0 && amount1Out < _reserve1, 'WinterswapV2: INSUFFICIENT_LIQUIDITY_FREE');

        uint balance0;
        uint balance1;
        { // scope for _token{0,1}, avoids stack too deep errors
            address _token0 = token0;
            address _token1 = token1;
            require(to != _token0 && to != _token1, 'WinterswapV2: INVALID_TO_FREE');
            if (amount0Out > 0) _safeTransfer(_token0, to, amount0Out); // optimistically transfer tokens
            if (amount1Out > 0) _safeTransfer(_token1, to, amount1Out); // optimistically transfer tokens
            if (data.length > 0) IWinterswapV2Callee(to).winterswapV2Call(msg.sender, amount0Out, amount1Out, data);
            balance0 = IHRC20(_token0).balanceOf(address(this));
            balance1 = IHRC20(_token1).balanceOf(address(this));
        }
        uint amount0In = balance0 > _reserve0 - amount0Out ? balance0 - (_reserve0 - amount0Out) : 0;
        uint amount1In = balance1 > _reserve1 - amount1Out ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, 'WinterswapV2: INSUFFICIENT_INPUT_AMOUNT_FREE');

        require(balance0.mul(balance1) >= uint(_reserve0).mul(_reserve1), 'WinterswapV2: K_FREE');


        _update(balance0, balance1, _reserve0, _reserve1);
        emit SwapFree(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }


    function transfer_tx_fee(
        uint256 amount,
        address token,
        address to
    ) override external lock onlyRouter{
        if (amount == 0 || token == to) return;
        (uint112 _reserve0, uint112 _reserve1, ) = getReserves();
        require(to != token0 && to != token1, 'WinterswapV2 PAIR : INVALID_TO');
        require(token == token0 || token == token1, 'WinterswapV2 PAIR : INVALID_TOKEN');

        _safeTransfer(token, to, amount);
        uint256 balance0 = IHRC20(token0).balanceOf(address(this));
        uint256 balance1 = IHRC20(token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        emit TransferTxFee(token, to , amount);
    }


    // force balances to match reserves
    function skim(address to) override external lock {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        _safeTransfer(_token0, to, IHRC20(_token0).balanceOf(address(this)).sub(reserve0));
        _safeTransfer(_token1, to, IHRC20(_token1).balanceOf(address(this)).sub(reserve1));
    }

    // force reserves to match balances
    function sync() override external lock {
        _update(IHRC20(token0).balanceOf(address(this)), IHRC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }
}
