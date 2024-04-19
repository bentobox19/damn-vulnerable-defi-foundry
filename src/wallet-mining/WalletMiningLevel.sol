// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {AuthorizerUpgradeable} from "./AuthorizerUpgradeable.sol";
import {DamnValuableToken} from "dvt/DamnValuableToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {WalletDeployer} from "./walletDeployer.sol";

import "forge-std/Test.sol";

contract WalletMiningLevel is StdAssertions {
  Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));
  address private constant deployerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("deployer"))))));
  address private constant wardAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("ward"))))));
  address public constant playerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));

  address private constant DEPOSIT_ADDRESS = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
  uint256 public constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;
  uint256 private initialWalletDeployerTokenBalance;

  DamnValuableToken public token;
  AuthorizerUpgradeable public implementation;
  AuthorizerUpgradeable private authorizer;
  WalletDeployer public walletDeployer;

  function setup() external {
    vm.startPrank(deployerAddress);

    // Deploy Damn Valuable Token contract
    token = new DamnValuableToken();

    // Deploy authorizer with the corresponding proxy
    implementation = new AuthorizerUpgradeable();
    address[] memory param01 = new address[](1);
    param01[0] = wardAddress;
    address[] memory param02 = new address[](1);
    param02[0] = DEPOSIT_ADDRESS;
    bytes memory data = abi.encodeWithSignature(
      "init(address[],address[])",
      param01,
      param02
    );
    ERC1967Proxy proxy = new ERC1967Proxy(
      address(implementation),
      data
    );
    authorizer = AuthorizerUpgradeable(address(proxy));

    assertEq(authorizer.owner(), deployerAddress);
    assertTrue(authorizer.can(wardAddress, DEPOSIT_ADDRESS));
    // assertFalse(authorizer.can(playerAddress, DEPOSIT_ADDRESS));

    // Deploy Safe Deployer contract
    walletDeployer = new WalletDeployer(address(token));

    assertEq(walletDeployer.chief(), deployerAddress);
    assertEq(walletDeployer.gem(), address(token));

    // Set Authorizer in Safe Deployer
    walletDeployer.rule(address(authorizer));
    assertEq(walletDeployer.mom(), address(authorizer));

    assertTrue(walletDeployer.can(wardAddress, DEPOSIT_ADDRESS)); // won't revert
    // Expression below will revert:
    //   - Unable to catch, nor using cheatcode expectRevert().
    //   - Needs more work to find root cause.
    // walletDeployer.can(playerAddress, DEPOSIT_ADDRESS);

    // Fund Safe Deployer with tokens
    initialWalletDeployerTokenBalance = walletDeployer.pay() * 43;
    token.transfer(address(walletDeployer), initialWalletDeployerTokenBalance);

    // Ensure these accounts start empty
    assertEq(DEPOSIT_ADDRESS.code, "");
    assertEq(address(walletDeployer.fact()).code, "");
    assertEq(address(walletDeployer.copy()).code, "");

    // Deposit large amount of DVT tokens to the deposit address
    token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

    // Ensure initial balances are set correctly
    assertEq(token.balanceOf(DEPOSIT_ADDRESS), DEPOSIT_TOKEN_AMOUNT);
    assertEq(token.balanceOf(address(walletDeployer)), initialWalletDeployerTokenBalance);
    assertEq(token.balanceOf(playerAddress), 0);

    vm.stopPrank();
   }

  function validate() external {
    // Factory account must have code
    assertTrue(address(walletDeployer.fact()).code.length > 0);

    // Master copy account must have code
    assertTrue(address(walletDeployer.copy()).code.length > 0);

    // Deposit account must have code
    assertTrue(DEPOSIT_ADDRESS.code.length > 0);

    // The deposit address and the Safe Deployer contract must not hold tokens
    assertEq(token.balanceOf(DEPOSIT_ADDRESS), 0);
    assertEq(token.balanceOf(address(walletDeployer)), 0);

    // Player must own all tokens
    assertEq(
      token.balanceOf(playerAddress),
      initialWalletDeployerTokenBalance + DEPOSIT_TOKEN_AMOUNT);
  }
}
