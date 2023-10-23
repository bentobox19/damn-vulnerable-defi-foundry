// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/backdoor/BackdoorLevel.sol";

contract BackdoorTest is Test {
  BackdoorLevel level = new BackdoorLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // level.validate();
  }
}
