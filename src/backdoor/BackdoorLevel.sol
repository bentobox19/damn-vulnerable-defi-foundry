// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {DamnValuableToken} from "dvt/DamnValuableToken.sol";
import {WalletRegistry} from "./WalletRegistry.sol";

import "forge-std/Test.sol";

contract BackdoorLevel is StdAssertions, StdCheats {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployer = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant alice = payable(address(uint160(uint256(keccak256(abi.encodePacked("alice"))))));
  address payable private constant bob = payable(address(uint160(uint256(keccak256(abi.encodePacked("bob"))))));
  address payable private constant charlie = payable(address(uint160(uint256(keccak256(abi.encodePacked("charlie"))))));
  address payable private constant david = payable(address(uint160(uint256(keccak256(abi.encodePacked("david"))))));
  address payable private constant player = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));
  address[] private users = [alice, bob, charlie, david];

  uint256 private constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;

  GnosisSafe private masterCopy;
  GnosisSafeProxyFactory private walletFactory;
  DamnValuableToken private token;
  WalletRegistry private walletRegistry;

  function setup() external {
    vm.startPrank(deployer);

    // Deploy Gnosis Safe master copy and factory contracts
    masterCopy = new GnosisSafe();
    walletFactory = new GnosisSafeProxyFactory();
    token = new DamnValuableToken();

    // Deploy the registry
    walletRegistry = new WalletRegistry(
      address(masterCopy),
      address(walletFactory),
      address(token),
      users
    );
    assertEq(walletRegistry.owner(), deployer);

    vm.stopPrank();

    for (uint8 i = 0; i < users.length; i++) {
      vm.startPrank(users[i]);
      // Users are registered as beneficiaries
      assertTrue(walletRegistry.beneficiaries(users[i]));

      // User cannot add beneficiaries
      vm.expectRevert(bytes4(keccak256(bytes("Unauthorized()"))));
      walletRegistry.addBeneficiary(users[i]);

      vm.stopPrank();
    }

    vm.startPrank(deployer);

    // Transfer tokens to be distributed to the registry
    token.transfer(address(walletRegistry), AMOUNT_TOKENS_DISTRIBUTED);

    vm.stopPrank();
  }

  function validate() external {
    for (uint8 i = 0; i < users.length; i++) {
      // User must have registered a wallet
      address wallet = walletRegistry.wallets(users[i]);
      assertNotEq(wallet, address(0));

      // User is no longer registered as a beneficiary
      assertFalse(walletRegistry.beneficiaries(users[i]));
    }

    assertEq(token.balanceOf(player), AMOUNT_TOKENS_DISTRIBUTED);
  }
}
