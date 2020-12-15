// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.7.0;

interface IWNS {
    function router() external view returns (address);
    function swap_factory() external view returns (address);
    function wht() external view returns (address);
    function snowman() external view returns (address);
    function snowball() external view returns (address);
    function farm() external view returns (address);
    function lottery() external view returns (address);
}
