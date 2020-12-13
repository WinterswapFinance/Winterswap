// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./HRC20.sol";
import "../../utils/Pausable.sol";

/**
 * @dev HRC20 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 */
abstract contract HRC20Pausable is HRC20, Pausable {
    /**
     * @dev See {HRC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        require(!paused(), "HRC20Pausable: token transfer while paused");
    }
}
