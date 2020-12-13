// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "../openzeppelin/token/HRC20/HRC20.sol";
import "../openzeppelin/access/Ownable.sol";

contract SnowExam is HRC20("SnowExam", "SNE"), Ownable {
    /// @notice Creates `_amount` token to `_to`. Must only be called by the owner (Farm).
    function mint(address _to, uint256 _amount) public onlyOwner {
        _mint(_to, _amount);
    }
}
