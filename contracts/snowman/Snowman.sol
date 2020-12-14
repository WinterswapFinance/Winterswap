// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../openzeppelin/token/HRC20/HRC20.sol";
import "../wns/IWNS.sol";

contract Snowman is HRC20("Snowman","SNM") {
    using SafeMath for uint256;

    IWNS wns;
    address snowball;

    // Define the Sushi token contract
    constructor(IWNS _wns) {
        wns = _wns;
    }

    function init() external{
        snowball = wns.snowball();
    }

    //snowball is 'growing', swap_fee will be converted into snowball and xfer into snowman factory
    function stake(uint256 _amount_snowball) public {
        IHRC20(snowball).transferFrom(msg.sender, address(this), _amount_snowball);
        // Gets the amount of snowball locked in the contract
        uint256 totalSnowball = IHRC20(snowball).balanceOf(address(this));
        // Gets the amount of snowman in existence
        uint256 totalSnowman = totalSupply();
        // init rate is 1:1
        if (totalSnowman == 0 || totalSnowball == 0) {
            _mint(msg.sender, _amount_snowball);
        }
        else {
            // amount / totalSnowball    *  totalSnowman
            uint256 to_mint = _amount_snowball.mul(totalSnowman).div(totalSnowball);
            _mint(msg.sender, to_mint);
        }
    }

    function refund(uint256 _amount_snowman) public {
        uint256 totalSnowman = totalSupply();

        uint256 to_return = _amount_snowman.mul(IHRC20(snowball).balanceOf(address(this))).div(totalSnowman);
        _burn(msg.sender, _amount_snowman);

        IHRC20(snowball).transfer(msg.sender, to_return);
    }
}
