// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
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
    address[] memory owners = new address[](1);
    owners[0] = level.aliceAddress();

    bytes memory initializer = abi.encodeWithSelector(
      GnosisSafe.setup.selector,
      owners,
      uint256(1),
      address(0),
      new bytes(0),
      address(0),
      address(0),
      uint256(0),
      address(0)
    );

    GnosisSafeProxyFactory(level.walletFactory())
      .createProxyWithCallback(
        address(level.masterCopy()),
        initializer,
        uint256(0x42),
        IProxyCreationCallback(level.walletRegistry())
      );

    // level.validate();
  }
}
