// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {Vault} from "../src/vault.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;
    IRebaseToken private iRebaseToken;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);

        rebaseToken = new RebaseToken();
        iRebaseToken = IRebaseToken(address(rebaseToken));

        vault = new Vault(iRebaseToken);
        rebaseToken.grantMintAndBurnRole(address(vault));

        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success, ) = payable(address(vault)).call{value: rewardAmount}(
            ""
        );
        if (!success) {
            revert();
        }
    }

    function testDepositLinear(uint256 amount) public {
        vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        // 2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance", startBalance);
        assertEq(startBalance, amount);
        // 3. wrap the time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 middleBalance = rebaseToken.balanceOf(user);
        console.log("middleBalance", middleBalance);
        assertGt(middleBalance, startBalance);
        // 4. wrap the time again by the same amount and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 endBalance = rebaseToken.balanceOf(user);
        console.log("endBalance", endBalance);
        assertGt(endBalance, startBalance);
        // 5. check the balance increase is linear
        assertApproxEqAbs(
            endBalance - middleBalance,
            middleBalance - startBalance,
            1
        );
        vm.stopPrank();
    }

    function testRedeem(uint256 amount) public {
        vm.assume(amount > 1e5);
        amount = bound(amount, 1e5, type(uint96).max);
        // 1. Deposit
        vm.startPrank(user);
        vm.deal(user, amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(user), amount);
        // 2. Redeem
        vault.redeem(amount);
        assertEq(rebaseToken.balanceOf(user), 0);
        assertEq(address(user).balance, amount);
        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(
        uint256 depositAmount,
        uint256 time
    ) public {
        time = bound(time, 1000, type(uint96).max); // this is a crazy number of years - 2^96 seconds is a lot
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // this is an Ether value of max 2^78 which is crazy

        // 1. Deposit
        vm.deal(user, depositAmount);
        vm.prank(user);
        vault.deposit{value: depositAmount}();

        // 2. Warp time
        vm.warp(time);
        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(user);

        // 2-b. Add the rewards to the vault
        vm.deal(owner, balanceAfterSomeTime - depositAmount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - depositAmount);
        // 3. Redeem
        vm.prank(user);
        vault.redeem(balanceAfterSomeTime);

        // 4. Check the balance
        uint256 ethBalance = address(user).balance;

        assertEq(ethBalance, balanceAfterSomeTime);
        assertGt(ethBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        // 1. Deposit
        vm.deal(user, amount);
        vm.prank(user);
        vault.deposit{value: amount}();

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2Balance = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount);
        assertEq(user2Balance, 0);

        // owner decreaces the interest rate
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // 2. Transfer
        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend);
        uint256 userBalanceAfterTransfer = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfterTransfer = rebaseToken.balanceOf(user2);
        assertEq(userBalanceAfterTransfer, userBalance - amountToSend);
        assertEq(user2BalanceAfterTransfer, amountToSend);

        // 3. check the user interest rate has been inherited (5e10) not (4e10)
        assertEq(rebaseToken.getUserInterestRate(user), 5e10);
        assertEq(rebaseToken.getUserInterestRate(user2), 5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurnRole() public {
        vm.prank(user);
        vm.expectRevert();
        rebaseToken.mint(user, 100);
        vm.expectRevert();
        rebaseToken.burn(user, 100);
    }
}
