// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/puppet/PuppetV2Level.sol";

contract PuppetTest is Test {
  PuppetV2Level level = new PuppetV2Level();

  function setUp() public {
    // level.setup();
  }

  function testExploit() public {
    // level.validate();
  }

  receive() external payable {}
}
