// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet-v2/PuppetV2Level.sol";

contract PuppetV2Test is Test {
  PuppetV2Level level = new PuppetV2Level();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    // level.validate();
  }

  receive() external payable {}
}
