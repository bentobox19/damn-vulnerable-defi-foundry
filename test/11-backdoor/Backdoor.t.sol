// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {IProxyCreationCallback} from "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";
import {BackdoorLevel} from "../../src/backdoor/BackdoorLevel.sol";

import "forge-std/Test.sol";

contract BackdoorTest is Test {
  BackdoorLevel private level = new BackdoorLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    GnosisSafeProxyFactory(level.walletFactory())
      .createProxyWithCallback(
        address(level.masterCopy()),
        abi.encodePacked(bytes4(0xb63e800d)),
        uint256(0x42),
        IProxyCreationCallback(level.walletRegistry())
      );

    // level.validate();
  }
}
