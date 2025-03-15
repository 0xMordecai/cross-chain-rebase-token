// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Mohamed Lahrach
 * @notice This is a cross-chain that incentivises users to deposit their tokens into a vault in order to earn rewards.
 * @notice The interest rate in the smart contrzct can lnly decrease.
 * @notice Each will user will have their own interest rate that is the globel interst rate in time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    // ERORRS
    error RebaseToken__InterestRateCanOnlyDecrease(
        uint256 oldInterestRate,
        uint256 newInterestRate
    );
    // STORAGE
    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 public constant MINT_AND_BURN_ROLE =
        keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = (5 * PRECISION_FACTOR) / 1e8; // 10^-8 == 1 / 10^8   5% interest rate
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_lastUpdatedTimesamp;

    // EVENTS
    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "ERT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice Set the interest rate in the smart contract
     * @param _newInterestRate The new interest rate
     * @dev The interest rate can only decrease
     */
    // @audit : everyone can set the interest rate
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        // set the interest rate
        if (_newInterestRate > s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(
                s_interestRate,
                _newInterestRate
            );
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /** 
     * @notice Get the principle balance of a user. This is the number of tokens that have actually been minted to the user, not including any interest that has accrued since the last time the user interacted with the protocol.
     * @param _user The user to get the principle balance for
     * @return The principle balance of the user

    */
    function principalBalanceOf(address _user) external view returns (uint256) {
        return super.balanceOf(_user);
    }

    /**
    * @notice Mint the user tokens when they deposit into the vault
    * @param _to The user to mint the tokens to
    * @param _amount The amount of tokens to mint

    */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     *@notice Burn the user tokens when they withdraw from the vault
     *@param _from The user to burn the tokens from
     *@param _amount The amount of tokens to burn

    */
    function burn(
        address _from,
        uint256 _amount
    ) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /*
   * @notice Transfer tokens from one user to another
    * @param _recipient The user to transfer the tokens to
    * @param _amount The amount of tokens to transfer
    * @return True if the transfer was successful

    */
    function transfer(
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transfer(_recipient, _amount);
    }

    /*
   * @notice Transfer tokens from one user to another
    * @param _sender The user to transfer the tokens from
    * @param _recipient The user to transfer the tokens to
    * @param _amount The amount of tokens to transfer
    * @return True if the transfer was successful

    */
    function transferFrom(
        address _sender,
        address _recipient,
        uint256 _amount
    ) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);
        if (_amount == type(uint256).max) {
            _amount = balanceOf(msg.sender);
        }
        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender];
        }
        return super.transferFrom(_sender, _recipient, _amount);
    }

    /**
     *@notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g. burn, mint, transfer)
     *@param _user The user to mint the accrued interest to

    */
    function _mintAccruedInterest(address _user) internal {
        // (1) find the current balance of rebase tokens that have been minted to user.
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        // (2) calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> (2) - (1)
        uint256 balanceIncrease = currentBalance - previousPrincipalBalance;
        // set the user last updated timestamp
        s_lastUpdatedTimesamp[_user] = block.timestamp;
        // call _mint to mint the tokens to the user
        _mint(_user, balanceIncrease);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        return
            (super.balanceOf(_user) *
                _calculateUserAccumulatedInterestSinceLastUpdate(_user)) /
            PRECISION_FACTOR;
    }

    function _calculateUserAccumulatedInterestSinceLastUpdate(
        address _user
    ) internal view returns (uint256) {
        // get the time since the last update
        // calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        //1. calculate the time since the last update
        //2. calculate the amount of linear growth
        //3. return the amount of linear growth
        // (user deposit amount * interest rate * time since slast update) / 1e18
        uint256 timeSinceLastUpdate = block.timestamp -
            s_lastUpdatedTimesamp[_user];

        uint256 linearInterset = PRECISION_FACTOR +
            (s_userInterestRate[_user] * timeSinceLastUpdate);

        return linearInterset;
    }

    ///////////////////////////////////////////
    //////////// GETTERS //////////////////////
    ///////////////////////////////////////////

    /*
    * @notice Get the interest rate for the contract
    * @return The interest rate for the contract

    */
    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    /**
     * @return Get the user's inerest rate
     * @param _user The user to get the interest rate for
     */
    function getUserInterestRate(
        address _user
    ) external view returns (uint256) {
        return s_userInterestRate[_user];
    }
}
