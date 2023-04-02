// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "forge-std/Test.sol";
import "../../src/truster/TrusterLevel.sol";

contract TrusterTest is Test {
  TrusterLevel level = new TrusterLevel();

  function setUp() public {
    level.setup();
  }

  function testExploit() public {
    level.validate();
  }
}
