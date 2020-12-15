// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../openzeppelin/token/HRC20/HRC20Capped.sol";
import "../wns/IWNS.sol";

contract Snowball is HRC20Capped {

    uint256 constant __cap__ = 10000000*10**18;

    address farm;
    address lottery;
    IWNS wns;

    modifier onlyPermitted() {
        require(msg.sender == farm || msg.sender == lottery, "Permitted: caller is neither farm nor lottery");
        _;
    }

    constructor(address dev, uint256 amount, IWNS _wns) HRC20Capped(__cap__) HRC20("Snowball","SNB"){
        if(dev != address(0) && amount !=0){
            _mint(dev, amount);
        }
        wns = _wns;
    }

    function init() external{
        farm = wns.farm();
        lottery = wns.lottery();
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (Farm).
    function mint(address _to, uint256 _amount) public onlyPermitted {
        _mint(_to, _amount);
    }
}
