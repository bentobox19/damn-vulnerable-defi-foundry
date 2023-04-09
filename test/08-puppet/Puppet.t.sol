// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet/PuppetLevel.sol";

contract PuppetTest is Test {
  PuppetLevel level = new PuppetLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
