// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../openzeppelin/token/HRC20/HRC20Capped.sol";
import "../openzeppelin/access/Ownable.sol";

contract Snowball is HRC20Capped, Ownable {

    uint256 constant __cap__ = 1000000000000000000*10000000;

    constructor(address dev) HRC20Capped(__cap__) HRC20("Snowball","SNB"){
        _mint(dev, 1000000000000000000*1000);
    }

    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (Farm).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
