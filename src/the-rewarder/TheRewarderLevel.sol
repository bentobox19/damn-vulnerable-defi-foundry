// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "forge-std/Vm.sol";

import "./FlashLoanerPool.sol";
import "./TheRewarderPool.sol";
import "../DamnValuableToken.sol";

contract TheRewarderLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant alice = payable(address(uint160(uint256(keccak256(abi.encodePacked("alice"))))));
  address payable private constant bob = payable(address(uint160(uint256(keccak256(abi.encodePacked("bob"))))));
  address payable private constant charlie = payable(address(uint160(uint256(keccak256(abi.encodePacked("charlie"))))));
  address payable private constant david = payable(address(uint160(uint256(keccak256(abi.encodePacked("david"))))));
  address payable[4] private users = [alice, bob, charlie, david];

  uint256 internal constant TOKENS_IN_LENDER_POOL = 1_000_000e18;

  DamnValuableToken internal liquidityToken;
  FlashLoanerPool internal flashLoanPool;
  TheRewarderPool internal rewarderPool;
  RewardToken internal rewardToken;
  AccountingToken internal accountingToken;

  function setup() external {
    vm.startPrank(deployer);

    liquidityToken = new DamnValuableToken();
    flashLoanPool = new FlashLoanerPool(address(liquidityToken));

    // Set initial token balance of the pool offering flash loans
    liquidityToken.transfer(address(flashLoanPool), TOKENS_IN_LENDER_POOL);

    rewarderPool = new TheRewarderPool(address(liquidityToken));
    rewardToken = rewarderPool.rewardToken();
    accountingToken = rewarderPool.accountingToken();

    // Check roles in accounting token
    assertEq(accountingToken.owner(), address(rewarderPool));
    assertTrue(accountingToken.hasAllRoles(
      address(rewarderPool),
      accountingToken.MINTER_ROLE() |
      accountingToken.SNAPSHOT_ROLE() |
      accountingToken.BURNER_ROLE()
    ));

    vm.stopPrank();

    // alice, bob, charlie and david deposit tokens
    uint256 depositAmount = 100e18;

    for (uint8 i = 0; i < users.length; i++) {
      vm.startPrank(deployer);
      liquidityToken.transfer(address(users[i]), depositAmount);
      vm.stopPrank();

      vm.startPrank(users[i]);
      liquidityToken.approve(address(rewarderPool), depositAmount);
      rewarderPool.deposit(depositAmount);
      vm.stopPrank();
    }

    assertEq(accountingToken.totalSupply(), depositAmount * users.length);
    assertEq(rewardToken.totalSupply(), 0);

    // advance time 5 days so that depositors can get rewards
    vm.warp(block.timestamp + 5 days);

    // each depositor gets reward tokens
    uint256 rewardsInRound = rewarderPool.REWARDS();
    for (uint8 i = 0; i < users.length; i++) {
      vm.startPrank(users[i]);
      rewarderPool.distributeRewards();
      assertEq(rewardToken.balanceOf(address(users[i])), rewardsInRound / users.length);
      vm.stopPrank();
    }

    assertEq(rewardToken.totalSupply(), rewardsInRound);

    // player starts with zero DVT tokens in balance
    assertEq(liquidityToken.balanceOf(msg.sender), 0);

    // two rounds must have occurred so far
    assertEq(rewarderPool.roundNumber(), 2);
  }

  function validate() external {
    assertEq(rewarderPool.roundNumber(), 3);

    // Users should get neglegible rewards this round
    for (uint8 i = 0; i < users.length; i++) {
      vm.startPrank(users[i]);
      rewarderPool.distributeRewards();
      uint256 userRewards = rewardToken.balanceOf(address(users[i]));
      uint256 delta = (userRewards - rewarderPool.REWARDS()) / users.length;
      assertLt(delta, 1e16);
      vm.stopPrank();
    }

    // Rewards must have been issued to the player account
    assertGt(rewardToken.totalSupply(), rewarderPool.REWARDS());
    uint256 playerRewards = rewardToken.balanceOf(msg.sender);
    assertGt(playerRewards, 0);

    // The amount of rewards earned should be close to total available amount
    uint256 delta = rewarderPool.REWARDS() - playerRewards;
    assertLt(delta, 1e17);

    // Balance of DVT tokens in player and lending pool hasn't changed
    assertEq(liquidityToken.balanceOf(msg.sender), 0);
    assertEq(liquidityToken.balanceOf(address(flashLoanPool)), TOKENS_IN_LENDER_POOL);
  }
}
