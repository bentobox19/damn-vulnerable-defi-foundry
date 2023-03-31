// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/unstoppable/UnstoppableLevel.sol";

contract UnstoppableTest is Test {
  UnstoppableLevel internal level = new UnstoppableLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
