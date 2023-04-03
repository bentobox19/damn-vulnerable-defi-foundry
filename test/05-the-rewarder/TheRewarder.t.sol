// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/the-rewarder/TheRewarderLevel.sol";

contract TheRewarderTest is Test {
  TheRewarderLevel level = new TheRewarderLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
