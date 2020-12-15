// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

import "../openzeppelin/access/Ownable.sol";
import "./IWNS.sol";

contract WNS is IWNS, Ownable{

    constructor(address _admin){
        transferOwnership(_admin);
    }

    address public override router;
    address public override swap_factory;
    address public override wht;
    address public override snowman;
    address public override snowball;
    address public override farm;
    address public override lottery;

    function setAll(address _router, address _swap_factory, address _wht,
        address _snowman, address _snowball, address _farm, address _lottery) external onlyOwner{
        router = _router;
        swap_factory = _swap_factory;
        wht = _wht;
        snowman = _snowman;
        snowball = _snowball;
        farm = _farm;
        lottery = _lottery;
    }
}
