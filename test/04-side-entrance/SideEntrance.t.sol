// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/side-entrance/SideEntranceLevel.sol";

contract SideEntranceTest is Test {
  SideEntranceLevel level = new SideEntranceLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
