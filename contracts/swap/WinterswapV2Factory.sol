// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import './interfaces/IWinterswapV2Factory.sol';
import './WinterswapV2Pair.sol';
import '../wns/IWNS.sol';

contract WinterswapV2Factory is IWinterswapV2Factory {
    address override public feeTo;
    address override public feeToSetter;

    IWNS wns;

    address router;

    mapping(address => mapping(address => address)) override public getPair;
    address[] override public allPairs;

    constructor(address _feeToSetter, IWNS _wns) {
        feeToSetter = _feeToSetter;
        wns = _wns;
    }

    function init() external{
        router = wns.router();
    }

    function allPairsLength() override external view returns (uint) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB) override external returns (address pair) {
        require(tokenA != tokenB, 'WinterswapV2: IDENTICAL_ADDRESSES');
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'WinterswapV2: ZERO_ADDRESS');
        require(getPair[token0][token1] == address(0), 'WinterswapV2: PAIR_EXISTS'); // single check is sufficient
        bytes memory bytecode = type(WinterswapV2Pair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IWinterswapV2Pair(pair).initialize(token0, token1, router);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) override external {
        require(msg.sender == feeToSetter, 'WinterswapV2: FORBIDDEN');
        feeTo = _feeTo;
    }

    function setFeeToSetter(address _feeToSetter) override external {
        require(msg.sender == feeToSetter, 'WinterswapV2: FORBIDDEN');
        feeToSetter = _feeToSetter;
    }
}
