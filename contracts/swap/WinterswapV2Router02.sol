// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import './interfaces/IWinterswapV2Factory.sol';
import './libraries/TransferHelper.sol';

import './interfaces/IWinterswapV2Router02.sol';
import './libraries/WinterswapV2Library.sol';
import './libraries/SafeMathSwap.sol';
import '../openzeppelin/token/HRC20/IHRC20.sol';
import '../wht/IWHT.sol';
import '../wns/IWNS.sol';
import "../snowball/Snowball.sol";
import "../snowman/Snowman.sol";

contract WinterswapV2Router02 is IWinterswapV2Router01 {
    using SafeMathSwap for uint;


    uint256 constant PERMILLE = 1000;
    uint256 constant SWAP_FEE_PERMILLE = 5;
    uint256 constant SWAP_FEE_TO_GOV_PERMILLE = 2;

    //except for WHT, due to 2300 :)
    address public WHT;
    address public override factory;
    address public snowball;
    address public snowman;

    IWNS wns;

    function ETH() override public view returns (address){
        return WHT;
    }

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'WinterswapV2Router: EXPIRED');
        _;
    }

    constructor(IWNS _wns) {
        wns = _wns;
    }

    function init() external{
        WHT = wns.wht();
        factory = wns.swap_factory();
        snowball = wns.snowball();
        snowman = wns.snowman();
    }

    receive() external payable {
        assert(msg.sender == WHT); // only accept WHT via fallback from the WHT contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IWinterswapV2Factory(factory).getPair(tokenA, tokenB) == address(0)) {
            IWinterswapV2Factory(factory).createPair(tokenA, tokenB);
        }

        (uint reserveA, uint reserveB) = WinterswapV2Library.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = WinterswapV2Library.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'WinterswapV2Router: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = WinterswapV2Library.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'WinterswapV2Router: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = WinterswapV2Library.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IWinterswapV2Pair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WHT,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = WinterswapV2Library.pairFor(factory, token, WHT);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWHT(WHT).deposit{value: amountETH}();
        assert(IWHT(WHT).transfer(pair, amountETH));
        liquidity = IWinterswapV2Pair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferWHT(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = WinterswapV2Library.pairFor(factory, tokenA, tokenB);
        IWinterswapV2Pair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IWinterswapV2Pair(pair).burn(to);
        (address token0,) = WinterswapV2Library.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'WinterswapV2Router: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'WinterswapV2Router: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WHT,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWHT(WHT).withdraw(amountETH);
        TransferHelper.safeTransferWHT(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = WinterswapV2Library.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? uint(-1) : liquidity;
        IWinterswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = WinterswapV2Library.pairFor(factory, token, WHT);
        uint value = approveMax ? uint(-1) : liquidity;
        IWinterswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
//    function removeLiquidityETHSupportingFeeOnTransferTokens(
//        address token,
//        uint liquidity,
//        uint amountTokenMin,
//        uint amountETHMin,
//        address to,
//        uint deadline
//    ) public virtual override ensure(deadline) returns (uint amountETH) {
//        (, amountETH) = removeLiquidity(
//            token,
//            WHT,
//            liquidity,
//            amountTokenMin,
//            amountETHMin,
//            address(this),
//            deadline
//        );
//        TransferHelper.safeTransfer(token, to, IHRC20(token).balanceOf(address(this)));
//        IWHT(WHT).withdraw(amountETH);
//        TransferHelper.safeTransferWHT(to, amountETH);
//    }
//    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
//        address token,
//        uint liquidity,
//        uint amountTokenMin,
//        uint amountETHMin,
//        address to,
//        uint deadline,
//        bool approveMax, uint8 v, bytes32 r, bytes32 s
//    ) external virtual override returns (uint amountETH) {
//        address pair = WinterswapV2Library.pairFor(factory, token, WHT);
//        uint value = approveMax ? uint(-1) : liquidity;
//        IWinterswapV2Pair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
//        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
//            token, liquidity, amountTokenMin, amountETHMin, to, deadline
//        );
//    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = WinterswapV2Library.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? WinterswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
            IWinterswapV2Pair(WinterswapV2Library.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }
    // transfer the 2/1000 of the 5/1000 from the pair to the snow factory
    // limited to Router
    function _swapFee(uint[] memory amounts, address[] memory path) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            uint fee = amounts[i].mul(SWAP_FEE_TO_GOV_PERMILLE) / PERMILLE;

            if(path[i] == snowball){
                //transfer snowball to snowman_factory
                address pair = WinterswapV2Library.pairFor(factory, path[i], path[i + 1]);
                IWinterswapV2Pair(pair).transfer_tx_fee(fee,path[i],snowman);
            }else{
                //swap the token to snowball and then transfer to snowman_factory
                //maybe the pair is XXXtoken<>snowball, we still need get it back and then swap_free it again
                //because get it back will update the K
                address pair = WinterswapV2Library.pairFor(factory, path[i], path[i + 1]);
                //token,from,to,value
                //this will update reserves and the K
                IWinterswapV2Pair(pair).transfer_tx_fee(fee,path[i],address(this));

                //now swap_free into snowball
                (address input, address output) = (path[i], snowball);

                IWinterswapV2Pair pair_free = IWinterswapV2Pair(IWinterswapV2Factory(factory).getPair(input, output));
                if (address(pair_free) == address(0)) {
                    return;
                }

                (uint reserveIn, uint reserveOut) = WinterswapV2Library.getReserves(factory, input, output);
                uint amountOut = WinterswapV2Library.getAmountOutFree(fee, reserveIn, reserveOut);
                (address token0,) = WinterswapV2Library.sortTokens(input, output);
                (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
                TransferHelper.safeTransferFrom(
                    input, address(this), address(pair_free), fee
                );
                pair_free.swap_free(
                    amount0Out, amount1Out, snowman, new bytes(0)
                );
            }

        }
    }
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        amounts = WinterswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        _swapFee(amounts, path);
    }
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        amounts = WinterswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'WinterswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
        _swapFee(amounts, path);
    }
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        require(path[0] == WHT, 'WinterswapV2Router: INVALID_PATH');
        amounts = WinterswapV2Library.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        IWHT(WHT).deposit{value: amounts[0]}();
        assert(IWHT(WHT).transfer(WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        _swapFee(amounts, path);
    }
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        require(path[path.length - 1] == WHT, 'WinterswapV2Router: INVALID_PATH');
        amounts = WinterswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'WinterswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferWHT(to, amounts[amounts.length - 1]);
        _swapFee(amounts, path);
    }
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        require(path[path.length - 1] == WHT, 'WinterswapV2Router: INVALID_PATH');
        amounts = WinterswapV2Library.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWHT(WHT).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferWHT(to, amounts[amounts.length - 1]);
        _swapFee(amounts, path);
    }
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path.length == 2, "WinterswapV2Router: SWAP_LENGTH_IS_LIMITED_TO_2");
        require(path[0] == WHT, 'WinterswapV2Router: INVALID_PATH');
        amounts = WinterswapV2Library.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'WinterswapV2Router: EXCESSIVE_INPUT_AMOUNT');
        IWHT(WHT).deposit{value: amounts[0]}();
        assert(IWHT(WHT).transfer(WinterswapV2Library.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferWHT(msg.sender, msg.value - amounts[0]);
        _swapFee(amounts, path);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
//    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
//        for (uint i; i < path.length - 1; i++) {
//            (address input, address output) = (path[i], path[i + 1]);
//            (address token0,) = WinterswapV2Library.sortTokens(input, output);
//            IWinterswapV2Pair pair = IWinterswapV2Pair(WinterswapV2Library.pairFor(factory, input, output));
//            uint amountInput;
//            uint amountOutput;
//            { // scope to avoid stack too deep errors
//            (uint reserve0, uint reserve1,) = pair.getReserves();
//            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
//            amountInput = IHRC20(input).balanceOf(address(pair)).sub(reserveInput);
//            amountOutput = WinterswapV2Library.getAmountOut(amountInput, reserveInput, reserveOutput);
//            }
//            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
//            address to = i < path.length - 2 ? WinterswapV2Library.pairFor(factory, output, path[i + 2]) : _to;
//            pair.swap(amount0Out, amount1Out, to, new bytes(0));
//        }
//    }
//    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
//        uint amountIn,
//        uint amountOutMin,
//        address[] calldata path,
//        address to,
//        uint deadline
//    ) external virtual override ensure(deadline) {
//        TransferHelper.safeTransferFrom(
//            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amountIn
//        );
//        uint balanceBefore = IHRC20(path[path.length - 1]).balanceOf(to);
//        _swapSupportingFeeOnTransferTokens(path, to);
//        require(
//            IHRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
//            'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
//        );
//
//    }
//    function swapExactETHForTokensSupportingFeeOnTransferTokens(
//        uint amountOutMin,
//        address[] calldata path,
//        address to,
//        uint deadline
//    )
//        external
//        virtual
//        override
//        payable
//        ensure(deadline)
//    {
//        require(path[0] == WHT, 'WinterswapV2Router: INVALID_PATH');
//        uint amountIn = msg.value;
//        IWHT(WHT).deposit{value: amountIn}();
//        assert(IWHT(WHT).transfer(WinterswapV2Library.pairFor(factory, path[0], path[1]), amountIn));
//        uint balanceBefore = IHRC20(path[path.length - 1]).balanceOf(to);
//        _swapSupportingFeeOnTransferTokens(path, to);
//        require(
//            IHRC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
//            'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT'
//        );
//    }
//    function swapExactTokensForETHSupportingFeeOnTransferTokens(
//        uint amountIn,
//        uint amountOutMin,
//        address[] calldata path,
//        address to,
//        uint deadline
//    )
//        external
//        virtual
//        override
//        ensure(deadline)
//    {
//        require(path[path.length - 1] == WHT, 'WinterswapV2Router: INVALID_PATH');
//        TransferHelper.safeTransferFrom(
//            path[0], msg.sender, WinterswapV2Library.pairFor(factory, path[0], path[1]), amountIn
//        );
//        _swapSupportingFeeOnTransferTokens(path, address(this));
//        uint amountOut = IHRC20(WHT).balanceOf(address(this));
//        require(amountOut >= amountOutMin, 'WinterswapV2Router: INSUFFICIENT_OUTPUT_AMOUNT');
//        IWHT(WHT).withdraw(amountOut);
//        TransferHelper.safeTransferWHT(to, amountOut);
//    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return WinterswapV2Library.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return WinterswapV2Library.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return WinterswapV2Library.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return WinterswapV2Library.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return WinterswapV2Library.getAmountsIn(factory, amountOut, path);
    }

    function pairFor(address tokenA, address tokenB) external view override returns (address pair){
        return WinterswapV2Library.pairFor(factory, tokenA, tokenB);
    }

    function pairCodeHash() external pure returns (bytes32){
        return WinterswapV2Library.pairCodeHash();
    }
}
