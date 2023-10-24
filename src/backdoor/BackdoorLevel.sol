// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {DamnValuableToken} from "dvt/DamnValuableToken.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {WalletRegistry} from "./WalletRegistry.sol";

import "forge-std/Test.sol";

contract BackdoorLevel is StdAssertions, StdCheats {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address payable private constant deployerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address payable private constant aliceAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("alice"))))));
  address payable private constant bobAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("bob"))))));
  address payable private constant charlieAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("charlie"))))));
  address payable private constant davidAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("david"))))));
  address payable public constant playerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));
  address[] public users = [aliceAddress, bobAddress, charlieAddress, davidAddress];

  uint256 private constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;

  GnosisSafe public masterCopy;
  GnosisSafeProxyFactory public walletFactory;
  DamnValuableToken public token;
  WalletRegistry public walletRegistry;

  function setup() external {
    vm.startPrank(deployerAddress);

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
    assertEq(walletRegistry.owner(), deployerAddress);

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

    vm.startPrank(deployerAddress);

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

    assertEq(token.balanceOf(playerAddress), AMOUNT_TOKENS_DISTRIBUTED);
  }

  // Little helper
  function getUsers() external view returns (address[] memory) {
    return users;
  }
}
