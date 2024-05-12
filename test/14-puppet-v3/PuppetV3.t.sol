// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet-v3/PuppetV3Level.sol";

contract PuppetV3Test is Test {
  PuppetV3Level level = new PuppetV3Level();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // level.validate();
  }
}
