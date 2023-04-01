// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/naive-receiver/NaiveReceiverLevel.sol";

contract NaiveReceiverTest is Test {
  NaiveReceiverLevel level = new NaiveReceiverLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
