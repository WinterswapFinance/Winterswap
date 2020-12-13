// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../swap/WinterswapV2Pair.sol";
import "../swap/libraries/WinterswapV2Library.sol";

contract CalcCodeHash {
    constructor(){

    }

    function codeHash() pure external returns(bytes32){
        bytes memory bytecode = type(WinterswapV2Pair).creationCode;
        bytes32 ret;
        assembly{
            ret := keccak256(add(bytecode, 0x20), mload(bytecode))
        }
        return ret;
    }

    function pairFor(address factory, address tokenA, address tokenB) external pure returns (address){
        return WinterswapV2Library.pairFor(factory,tokenA,tokenB);
    }
}
