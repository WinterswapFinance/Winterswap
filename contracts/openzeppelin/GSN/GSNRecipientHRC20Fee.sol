// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./GSNRecipient.sol";
import "../math/SafeMath.sol";
import "../access/Ownable.sol";
import "../token/HRC20/SafeHRC20.sol";
import "../token/HRC20/HRC20.sol";

/**
 * @dev A xref:ROOT:gsn-strategies.adoc#gsn-strategies[GSN strategy] that charges transaction fees in a special purpose HRC20
 * token, which we refer to as the gas payment token. The amount charged is exactly the amount of Ether charged to the
 * recipient. This means that the token is essentially pegged to the value of Ether.
 *
 * The distribution strategy of the gas payment token to users is not defined by this contract. It's a mintable token
 * whose only minter is the recipient, so the strategy must be implemented in a derived contract, making use of the
 * internal {_mint} function.
 */
contract GSNRecipientHRC20Fee is GSNRecipient {
    using SafeHRC20 for __unstable__HRC20Owned;
    using SafeMath for uint256;

    enum GSNRecipientHRC20FeeErrorCodes {
        INSUFFICIENT_BALANCE
    }

    __unstable__HRC20Owned private _token;

    /**
     * @dev The arguments to the constructor are the details that the gas payment token will have: `name` and `symbol`. `decimals` is hard-coded to 18.
     */
    constructor(string memory name, string memory symbol) {
        _token = new __unstable__HRC20Owned(name, symbol);
    }

    /**
     * @dev Returns the gas payment token.
     */
    function token() public view returns (IHRC20) {
        return IHRC20(_token);
    }

    /**
     * @dev Internal function that mints the gas payment token. Derived contracts should expose this function in their public API, with proper access control mechanisms.
     */
    function _mint(address account, uint256 amount) internal virtual {
        _token.mint(account, amount);
    }

    /**
     * @dev Ensures that only users with enough gas payment token balance can have transactions relayed through the GSN.
     */
    function acceptRelayedCall(
        address,
        address from,
        bytes memory,
        uint256 transactionFee,
        uint256 gasPrice,
        uint256,
        uint256,
        bytes memory,
        uint256 maxPossibleCharge
    )
        public
        view
        virtual
        override
        returns (uint256, bytes memory)
    {
        if (_token.balanceOf(from) < maxPossibleCharge) {
            return _rejectRelayedCall(uint256(GSNRecipientHRC20FeeErrorCodes.INSUFFICIENT_BALANCE));
        }

        return _approveRelayedCall(abi.encode(from, maxPossibleCharge, transactionFee, gasPrice));
    }

    /**
     * @dev Implements the precharge to the user. The maximum possible charge (depending on gas limit, gas price, and
     * fee) will be deducted from the user balance of gas payment token. Note that this is an overestimation of the
     * actual charge, necessary because we cannot predict how much gas the execution will actually need. The remainder
     * is returned to the user in {_postRelayedCall}.
     */
    function _preRelayedCall(bytes memory context) internal virtual override returns (bytes32) {
        (address from, uint256 maxPossibleCharge) = abi.decode(context, (address, uint256));

        // The maximum token charge is pre-charged from the user
        _token.safeTransferFrom(from, address(this), maxPossibleCharge);

        return 0;
    }

    /**
     * @dev Returns to the user the extra amount that was previously charged, once the actual execution cost is known.
     */
    function _postRelayedCall(bytes memory context, bool, uint256 actualCharge, bytes32) internal virtual override {
        (address from, uint256 maxPossibleCharge, uint256 transactionFee, uint256 gasPrice) =
            abi.decode(context, (address, uint256, uint256, uint256));

        // actualCharge is an _estimated_ charge, which assumes postRelayedCall will use all available gas.
        // This implementation's gas cost can be roughly estimated as 10k gas, for the two SSTORE operations in an
        // HRC20 transfer.
        uint256 overestimation = _computeCharge(_POST_RELAYED_CALL_MAX_GAS.sub(10000), gasPrice, transactionFee);
        actualCharge = actualCharge.sub(overestimation);

        // After the relayed call has been executed and the actual charge estimated, the excess pre-charge is returned
        _token.safeTransfer(from, maxPossibleCharge.sub(actualCharge));
    }
}

/**
 * @title __unstable__HRC20Owned
 * @dev An HRC20 token owned by another contract, which has minting permissions and can use transferFrom to receive
 * anyone's tokens. This contract is an internal helper for GSNRecipientHRC20Fee, and should not be used
 * outside of this context.
 */
// solhint-disable-next-line contract-name-camelcase
contract __unstable__HRC20Owned is HRC20, Ownable {
    uint256 private constant _UINT256_MAX = 2**256 - 1;

    constructor(string memory name, string memory symbol) HRC20(name, symbol) { }

    // The owner (GSNRecipientHRC20Fee) can mint tokens
    function mint(address account, uint256 amount) public onlyOwner {
        _mint(account, amount);
    }

    // The owner has 'infinite' allowance for all token holders
    function allowance(address tokenOwner, address spender) public view override returns (uint256) {
        if (spender == owner()) {
            return _UINT256_MAX;
        } else {
            return super.allowance(tokenOwner, spender);
        }
    }

    // Allowance for the owner cannot be changed (it is always 'infinite')
    function _approve(address tokenOwner, address spender, uint256 value) internal override {
        if (spender == owner()) {
            return;
        } else {
            super._approve(tokenOwner, spender, value);
        }
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        if (recipient == owner()) {
            _transfer(sender, recipient, amount);
            return true;
        } else {
            return super.transferFrom(sender, recipient, amount);
        }
    }
}
