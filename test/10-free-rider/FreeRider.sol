// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/free-rider/FreeRiderLevel.sol";

contract FreeRiderTest is Test {
  FreeRiderLevel level = new FreeRiderLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // level.validate();
  }
}
