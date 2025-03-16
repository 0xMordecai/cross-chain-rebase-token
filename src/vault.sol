// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    // We are going to need to pass the token address to the constructor so we can mint and burn.
    // We need to create a deposit function that mints tokens to the user and a redeem function that burns tokens from the user and sends the user the ETH.
    // We also need a way to add rewards to the vault.

    error Vault__RedeemTransferFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken _rebaseToken) {
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {}

    /**
     * @notice Allows users to deposit ETH into the vault and mint tokens to the user
     */
    function deposit() external payable {
        // Mint tokens to the user

        emit Deposit(msg.sender, msg.value);
        i_rebaseToken.mint(
            msg.sender,
            msg.value,
            i_rebaseToken.getInterestRate()
        );
    }

    /**
     * @notice Allows users to redeem tokens for ETH
     * @param _amount The amount of tokens to redeem
     */
    function redeem(uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = i_rebaseToken.balanceOf((msg.sender));
        }
        // 1. Burn tokens from the user
        i_rebaseToken.burn(msg.sender, _amount);
        // 2. Send the user the ETH
        (bool success, ) = payable(msg.sender).call{value: _amount}("");
        if (!success) {
            revert Vault__RedeemTransferFailed();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
