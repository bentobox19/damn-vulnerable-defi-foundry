// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/compromised/CompromisedLevel.sol";

contract CompromisedTest is Test {
  CompromisedLevel level = new CompromisedLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
