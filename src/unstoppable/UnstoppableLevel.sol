// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";

import "./UnstoppableVault.sol";
import "./ReceiverUnstoppable.sol";
import "../DamnValuableToken.sol";

contract UnstoppableLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant someUser = payable(address(uint160(uint256(keccak256(abi.encodePacked("someUser"))))));

  uint256 internal constant TOKENS_IN_VAULT = 1_000_000e18;
  uint256 internal constant INITIAL_PLAYER_TOKEN_BALANCE = 10e18;

  DamnValuableToken public token;
  UnstoppableVault public vault;
  ReceiverUnstoppable internal receiverContract;

  function setup() external {
    vm.startPrank(deployer);

    token = new DamnValuableToken();
    vault = new UnstoppableVault(token, deployer, deployer);
    assertEq(address(vault.asset()), address(token));

    token.approve(address(vault), TOKENS_IN_VAULT);
    vault.deposit(TOKENS_IN_VAULT, deployer);
    assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
    assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
    assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
    assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
    assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50_000e18);

    token.transfer(msg.sender, INITIAL_PLAYER_TOKEN_BALANCE);
    assertEq(token.balanceOf(msg.sender), INITIAL_PLAYER_TOKEN_BALANCE);

    vm.stopPrank();

    // show it's possible for someUser to take out a flash loan
    vm.startPrank(someUser);

    receiverContract = new ReceiverUnstoppable(address(vault));
    receiverContract.executeFlashLoan(100e18);

    vm.stopPrank();
   }

  function validate() external {
    vm.startPrank(someUser);

    vm.expectRevert();
    receiverContract.executeFlashLoan(100e18);

    vm.stopPrank();
  }
}
