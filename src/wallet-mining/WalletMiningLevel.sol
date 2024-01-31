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
  address private constant playerAddress = payable(address(uint160(uint256(keccak256(abi.encodePacked("player"))))));

  address private constant DEPOSIT_ADDRESS = 0x9B6fb606A9f5789444c17768c6dFCF2f83563801;
  uint256 private constant DEPOSIT_TOKEN_AMOUNT = 20_000_000e18;
  uint256 private initialWalletDeployerTokenBalance;

  DamnValuableToken private token;
  AuthorizerUpgradeable private authorizer;
  WalletDeployer private walletDeployer;

  function setup() external {
    vm.startPrank(deployerAddress);

    // Deploy Damn Valuable Token contract
    token = new DamnValuableToken();

    // Deploy authorizer with the corresponding proxy
    AuthorizerUpgradeable implementation = new AuthorizerUpgradeable();
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
    assertFalse(authorizer.can(playerAddress, DEPOSIT_ADDRESS));

    // Deploy Safe Deployer contract
    walletDeployer = new WalletDeployer(address(token));

    assertEq(walletDeployer.chief(), deployerAddress);
    assertEq(walletDeployer.gem(), address(token));

    // Set Authorizer in Safe Deployer
    walletDeployer.rule(address(authorizer));

    // Fund Safe Deployer with tokens
    initialWalletDeployerTokenBalance = walletDeployer.pay() * 43;
    token.transfer(address(walletDeployer), initialWalletDeployerTokenBalance);

    // Ensure these accounts start empty
    // ?

    // Deposit large amount of DVT tokens to the deposit address
    token.transfer(DEPOSIT_ADDRESS, DEPOSIT_TOKEN_AMOUNT);

    // Ensure initial balances are set correctly
    // ?

    vm.stopPrank();
   }

  function validate() external {
    // ?
  }
}
